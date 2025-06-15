// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// --- Import necessary Chainlink contracts ---
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
// No longer need ConfirmedOwner import
// import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";


/**
 * @title DeFiAIChatbot (Final Corrected Version)
 * @dev Core smart contract for the DeFi AI Chatbot.
 */
// ERROR_FIX 1: Removed `ConfirmedOwner` from the inheritance list to resolve the function clash.
contract DeFiAIChatbot is FunctionsClient, CCIPReceiver {

    // --- Chainlink Functions Configuration & State Variables ---
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    
    uint64 public s_subscriptionId;
    bytes32 public s_onchainDataFunctionsId;
    bytes32 public s_aiApiCallFunctionsId;

    // --- Events for Frontend Communication ---
    event AiResponseReceived(bytes32 indexed requestId, string response);
    event OnchainDataReceived(bytes32 indexed requestId, string data);
    event RequestFailed(bytes32 indexed requestId, string error);
    event CCIPMessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        bytes sender,
        bytes data,
        Client.EVMTokenAmount[] tokenAmounts
    );

    /**
     * @dev Constructor to initialize the contract.
     * @param functionsRouter The address of the Chainlink Functions Router contract.
     * @param ccipRouter The address of the Chainlink CCIP Router contract.
     * @param subscriptionId The ID of the Chainlink Functions subscription (uint64).
     */
    constructor(address functionsRouter, address ccipRouter, uint64 subscriptionId)
        FunctionsClient(functionsRouter)
        CCIPReceiver(ccipRouter)
        // ERROR_FIX 2: Removed `ConfirmedOwner(msg.sender)` call.
        // The `Owner` contract, inherited via `FunctionsClient`, sets msg.sender as the owner automatically.
    {
        s_subscriptionId = subscriptionId;
    }

    /**
     * @dev Sets the Chainlink Functions source IDs after contract deployment.
     * The `onlyOwner` modifier is inherited from FunctionsClient -> Owner.
     */
    function setFunctionsSourceIds(bytes32 onchainDataId, bytes32 aiApiCallId) external onlyOwner {
        s_onchainDataFunctionsId = onchainDataId;
        s_aiApiCallFunctionsId = aiApiCallId;
    }

    /**
     * @dev Requests on-chain data via Chainlink Functions.
     */
    function requestOnchainData(
        string calldata query,
        bytes32 donId,
        uint32 gasLimit
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForExternalJavaScript(s_onchainDataFunctionsId);
        
        string[] memory args = new string[](1);
        args[0] = query;
        req.setArgs(args);

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
     */
    function requestAIAssistance(
        string calldata userPrompt,
        string calldata onchainContext,
        bytes32 donId,
        uint32 gasLimit
    ) external returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForExternalJavaScript(s_aiApiCallFunctionsId);

        string[] memory args = new string[](2);
        args[0] = userPrompt;
        args[1] = onchainContext;
        req.setArgs(args);

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
            emit AiResponseReceived(requestId, string(response));
        }
    }

    /**
     * @dev Implements the abstract `_ccipReceive` function from `CCIPReceiver`.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        emit CCIPMessageReceived(
            message.messageId,
            message.sourceChainSelector,
            message.sender,
            message.data,
            message.tokenAmounts
        );
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