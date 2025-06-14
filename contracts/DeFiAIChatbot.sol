// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/FunctionsClient.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

/**
 * @title DeFiAIChatbot
 * @dev Core smart contract for the DeFi AI Chatbot, handling requests to Chainlink Functions
 * for onchain data and AI API calls, and receiving responses.
 */
contract DeFiAIChatbot is FunctionsClient, CCIPReceiver, ConfirmedOwner {

    // Chainlink Functions specific variables
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Configuration for Chainlink Functions
    address public s_router;
    uint64 public s_subscriptionId;

    // Chainlink Functions Source IDs (replace with your deployed Function IDs)
    bytes32 public s_onchainDataFunctionsId;
    bytes32 public s_aiApiCallFunctionsId;

    // Events to communicate AI responses and onchain data back to the frontend
    event AiResponseReceived(bytes32 indexed requestId, string response);
    event OnchainDataReceived(bytes32 indexed requestId, string data);
    event RequestFailed(bytes32 indexed requestId, string error);

    constructor(address router, uint66 subscriptionId)
        FunctionsClient(router)
        CCIPReceiver(router) // Assuming the same router for CCIPReceiver
        ConfirmedOwner(msg.sender) // Owner is the deployer
    {
        s_router = router;
        s_subscriptionId = subscriptionId;
    }

    /**
     * @dev Sets the Chainlink Functions source IDs after deployment.
     * @param onchainDataId The bytes32 ID of the deployed Chainlink Function for onchain data.
     * @param aiApiCallId The bytes32 ID of the deployed Chainlink Function for AI API calls.
     */
    function setFunctionsSourceIds(bytes32 onchainDataId, bytes32 aiApiCallId) external onlyOwner {
        s_onchainDataFunctionsId = onchainDataId;
        s_aiApiCallFunctionsId = aiApiCallId;
    }

    /**
     * @dev Requests onchain data via Chainlink Functions.
     * @param query The specific data query or parameters for the onchain data function.
     * @param donId The DON ID for the Chainlink Function.
     * @param gasLimit The maximum gas to use for the Chainlink Function execution.
     * @return requestId The ID of the Chainlink Functions request.
     */
    function requestOnchainData(
        string calldata query,
        bytes32 donId,
        uint32 gasLimit
    ) external onlyOwner returns (bytes32 requestId) { // Changed to onlyOwner for simplicity; consider more complex access control
        // Build the request bytes with the query as an argument
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_onchainDataFunctionsId); // Use the ID for onchain data
        req.setArgsBytes(abi.encodePacked(query));

        requestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            gasLimit,
            donId
        );
        s_lastRequestId = requestId;
        return requestId;
    }

    /**
     * @dev Requests AI assistance via Chainlink Functions.
     * @param userPrompt The user's natural language query/prompt.
     * @param onchainContext A JSON string or similar containing relevant onchain data context.
     * @param donId The DON ID for the Chainlink Function.
     * @param gasLimit The maximum gas to use for the Chainlink Function execution.
     * @return requestId The ID of the Chainlink Functions request.
     */
    function requestAIAssistance(
        string calldata userPrompt,
        string calldata onchainContext,
        bytes32 donId,
        uint32 gasLimit
    ) external returns (bytes32 requestId) {
        // Build the request bytes with userPrompt and onchainContext as arguments
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_aiApiCallFunctionsId); // Use the ID for AI API calls
        req.setArgs(string.concat(userPrompt, "|", onchainContext)); // Simple delimiter for multiple args

        requestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            gasLimit,
            donId
        );
        s_lastRequestId = requestId;
        return requestId;
    }

    /**
     * @dev Callback function called by Chainlink Functions to fulfill requests.
     * @param requestId The ID of the request being fulfilled.
     * @param response The raw bytes response from the Chainlink Function.
     * @param err The raw bytes error from the Chainlink Function, if any.
     */
    function rawFulfill(
        bytes32 requestId,
        bytes calldata response,
        bytes calldata err
    ) internal override {
        if (err.length > 0) {
            s_lastError = err;
            emit RequestFailed(requestId, string(err));
        } else {
            s_lastResponse = response;
            // Assuming response type can differentiate, or logic in JS handles
            // Here, we'll just emit a general response event.
            // In a real app, you might parse `response` to determine if it's AI or onchain data.
            emit AiResponseReceived(requestId, string(response));
        }
    }

    // --- Utility functions for testing/viewing last results ---
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