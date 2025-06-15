// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// --- Import necessary Chainlink contracts ---
// FunctionsClient: Base contract for interacting with Chainlink Functions.
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
// FunctionsRequest: Library for building and encoding Chainlink Functions requests.
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
// CCIPReceiver: Abstract contract for receiving Cross-Chain Interoperability Protocol (CCIP) messages.
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
// Client: Contains data structures like Any2EVMMessage for CCIP message handling.
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
// ConfirmedOwner: Provides basic ownership functionality (onlyOwner modifier).
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";


/**
 * @title DeFiAIChatbot
 * @dev Core smart contract for the DeFi AI Chatbot.
 * It handles sending requests to Chainlink Functions for on-chain data and AI API calls,
 * receiving their responses, and also demonstrates the capability to receive
 * cross-chain messages via Chainlink CCIP.
 */
contract DeFiAIChatbot is FunctionsClient, CCIPReceiver, ConfirmedOwner {

    // --- Chainlink Functions Configuration & State Variables ---
    // FunctionsRequest library is used to encode/decode Function requests.
    using FunctionsRequest for FunctionsRequest.Request;

    // Stores the ID of the last Chainlink Functions request sent from this contract.
    bytes32 public s_lastRequestId;
    // Stores the raw bytes response from the last successful Chainlink Functions call.
    bytes public s_lastResponse;
    // Stores the raw bytes error from the last failed Chainlink Functions call.
    bytes public s_lastError;

    // The address of the Chainlink Functions Router contract on the current blockchain.
    address public s_router;
    // The ID of the Chainlink Functions billing subscription used by this contract.
    // Chainlink Functions subscription IDs are always uint64.
    uint64 public s_subscriptionId;

    // Chainlink Functions Source IDs: These are identifiers for your deployed JavaScript
    // source code on the Chainlink Functions Decentralized Oracle Network (DON).
    // Replace these with the actual IDs of your deployed Functions.
    bytes32 public s_onchainDataFunctionsId;
    bytes32 public s_aiApiCallFunctionsId;

    // --- Events for Frontend Communication ---
    // Emitted when an AI response is successfully received from Chainlink Functions.
    event AiResponseReceived(bytes32 indexed requestId, string response);
    // Emitted when on-chain data is successfully received from Chainlink Functions.
    event OnchainDataReceived(bytes32 indexed requestId, string data);
    // Emitted when a Chainlink Functions request fails.
    event RequestFailed(bytes32 indexed requestId, string error);
    // Emitted when a cross-chain message is successfully received via CCIP.
    // Note: This event is already defined in CCIPReceiver, but re-declaring it
    // with the exact signature is generally fine and can sometimes help with tooling.
    event CCIPMessageReceived(
        bytes32 indexed messageId,
        // Using uint64 for sourceChainSelector as it's the standard for Chainlink chain selectors.
        uint64 indexed sourceChainSelector,
        bytes sender,
        bytes data,
        Client.EVMTokenAmount[] tokenAmounts
    );


    /**
     * @dev Constructor to initialize the contract.
     * It sets the Chainlink Functions router address, the subscription ID,
     * and designates the deployer of the contract as the owner.
     * @param router The address of the Chainlink Functions Router contract.
     * @param subscriptionId The ID of the Chainlink Functions subscription (uint64).
     */
    constructor(address router, uint64 subscriptionId)
        FunctionsClient(router)      // Initializes FunctionsClient with the router address.
        CCIPReceiver(router)         // Correctly initializes CCIPReceiver with the router address.
        ConfirmedOwner(msg.sender)   // Initializes ConfirmedOwner, setting the deployer as owner.
    {
        // Store the router address and subscription ID in state variables.
        s_router = router;
        s_subscriptionId = subscriptionId;
    }

    /**
     * @dev Sets the Chainlink Functions source IDs after contract deployment.
     * These IDs point to the specific JavaScript code snippets deployed on Chainlink Functions
     * that perform the requested operations.
     * This function can only be called by the contract owner.
     * @param onchainDataId The bytes32 ID of the deployed Chainlink Function for on-chain data queries.
     * @param aiApiCallId The bytes32 ID of the deployed Chainlink Function for AI API calls.
     */
    function setFunctionsSourceIds(bytes32 onchainDataId, bytes32 aiApiCallId) external onlyOwner {
        s_onchainDataFunctionsId = onchainDataId;
        s_aiApiCallFunctionsId = aiApiCallId;
    }

    /**
     * @dev Requests on-chain data via Chainlink Functions.
     * This function constructs and sends a request to a pre-configured Chainlink Function
     * designed to fetch and process specific data directly from the blockchain.
     * @param query The specific data query or parameters for the on-chain data function (e.g., "latest ETH price").
     * This string will be passed as an argument to the Chainlink Function's JavaScript.
     * @param donId The Decentralized Oracle Network (DON) ID that will execute this Function request.
     * @param gasLimit The maximum gas allowed for the Chainlink Function's off-chain computation.
     * @return requestId The unique ID generated for this Chainlink Functions request.
     */
    function requestOnchainData(
        string calldata query,
        bytes32 donId,
        uint32 gasLimit
    ) external onlyOwner returns (bytes32 requestId) {
        // Create a new FunctionsRequest object.
        FunctionsRequest.Request memory req;
        // Initialize the request for an inline JavaScript source, using the predefined ID for on-chain data.
        req.initializeRequestForInlineJavaScript(s_onchainDataFunctionsId);
        // Encode the query string and set it as an argument for the JavaScript function.
        req.setArgsBytes(abi.encodePacked(query));

        // Send the request to the Chainlink Functions Router.
        // _sendRequest is an internal function provided by the FunctionsClient.sol base contract.
        requestId = _sendRequest(
            req.encodeCBOR(),   // The request encoded into CBOR (Concise Binary Object Representation) format.
            s_subscriptionId,   // The Chainlink Functions billing subscription ID.
            gasLimit,           // The maximum gas limit for the off-chain computation.
            donId               // The DON ID responsible for executing the Function.
        );
        s_lastRequestId = requestId; // Store the last request ID for tracking purposes.
        return requestId;
    }

    /**
     * @dev Requests AI assistance via Chainlink Functions.
     * This function sends a user prompt and optional on-chain context to a Chainlink Function
     * that is designed to interact with an external AI API (e.g., Gemini, OpenAI) and get a response.
     * @param userPrompt The user's natural language query/prompt for the AI.
     * @param onchainContext A JSON string or similar containing relevant on-chain data context
     * that the AI might need to inform its response.
     * @param donId The DON ID for the Chainlink Function.
     * @param gasLimit The maximum gas to use for the Chainlink Function execution.
     * @return requestId The unique ID generated for this Chainlink Functions request.
     */
    function requestAIAssistance(
        string calldata userPrompt,
        string calldata onchainContext,
        bytes32 donId,
        uint32 gasLimit
    ) external returns (bytes32 requestId) { // This function is public (not onlyOwner) to allow anyone to interact with the AI bot.
        // Create a new FunctionsRequest object.
        FunctionsRequest.Request memory req;
        // Initialize the request for an inline JavaScript source, using the predefined ID for AI API calls.
        req.initializeRequestForInlineJavaScript(s_aiApiCallFunctionsId);
        // Set arguments for the JavaScript function. We concatenate the user prompt and on-chain context
        // with a simple "|" delimiter. The JavaScript code on Chainlink Functions will need to parse this.
        req.setArgs(string.concat(userPrompt, "|", onchainContext));

        // Send the request to the Chainlink Functions Router.
        requestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            gasLimit,
            donId
        );
        s_lastRequestId = requestId; // Store the last request ID.
        return requestId;
    }

    /**
     * @dev Callback function called by Chainlink Functions to fulfill requests.
     * This function is automatically invoked by the Chainlink Functions Router after
     * the off-chain computation (either on-chain data retrieval or AI API call) has completed.
     * It overrides the `rawFulfill` function inherited from `FunctionsClient.sol`.
     * @param requestId The ID of the request being fulfilled.
     * @param response The raw bytes response from the Chainlink Function (if successful).
     * @param err The raw bytes error message from the Chainlink Function (if an error occurred).
     */
    function rawFulfill(
        bytes32 requestId,
        bytes calldata response,
        bytes calldata err
    ) internal override {
        if (err.length > 0) {
            // If an error occurred during the Chainlink Function execution, store the error
            // and emit a RequestFailed event for frontend notification.
            s_lastError = err;
            emit RequestFailed(requestId, string(err));
        } else {
            // If the request was successful, store the response.
            s_lastResponse = response;
            // In a more complex application, you might add logic here to differentiate
            // between AI responses and on-chain data responses (e.g., by checking the requestId
            // against stored requests, or by a specific format/prefix in the response itself).
            // For this example, we'll emit a general AI response event.
            emit AiResponseReceived(requestId, string(response));
            // Alternatively, if you know this requestId was for on-chain data:
            // emit OnchainDataReceived(requestId, string(response));
        }
    }

    /**
     * @dev Implements the abstract `_ccipReceive` function from `CCIPReceiver`.
     * This function is the entry point for handling incoming cross-chain messages
     * delivered to this contract by the Chainlink CCIP Router.
     * Your custom logic for processing these messages should be implemented here.
     * @param message The `Client.Any2EVMMessage` struct containing all details of the received CCIP message.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal pure override {
        // This is where you will add your specific logic to process the incoming CCIP message.
        // For demonstration, we'll just emit an event with the received message details.
        // In a real application, you would typically decode `message.data` and
        // process `message.tokenAmounts` to perform actions relevant to your DApp.

        emit CCIPMessageReceived(
            message.messageId,
            message.sourceChainSelector, // The unique ID of the source chain.
            message.sender,              // The sender's address (encoded bytes).
            message.data,                // The arbitrary data payload.
            message.tokenAmounts         // Any tokens transferred with the message.
        );

        // Example of how you might decode and use the data:
        // string memory receivedText = abi.decode(message.data, (string));
        // // Now you can work with 'receivedText' to update state, trigger functions, etc.
        // // e.g., if (keccak256(abi.encodePacked(receivedText)) == keccak256(abi.encodePacked("performAction"))) { ... }

        // Important: If you don't fully handle a message, you might want to revert
        // or have a specific error handling mechanism. For now, this is a placeholder.
        // require(false, "CCIP message received but not explicitly handled by contract logic.");
    }


    // --- Utility functions for testing/viewing last results ---
    // These functions allow external callers to view the last request ID, response, or error
    // from Chainlink Functions calls made by this contract.

    function getLastRequestId() external view returns (bytes32) {
        return s_lastRequestId;
    }

    function getLastResponse() external view returns (bytes memory) {
        return s_lastResponse;
    }

    function getLastError() external view returns (bytes memory) {
        return s_lastError;
    }
}
