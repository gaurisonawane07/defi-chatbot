// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DeFiAIChatbot is FunctionsClient, CCIPReceiver, Ownable {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint64 public s_subscriptionId;

    // FIXED: Correctly declared state variables as strings
    string public s_onchainDataSource;
    string public s_aiApiCallSource;

    event AiResponseReceived(bytes32 indexed requestId, string response);
    event RequestFailed(bytes32 indexed requestId, string error);
    event CCIPMessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        bytes sender,
        bytes data,
        Client.EVMTokenAmount[] tokenAmounts
    );

    constructor(address functionsRouter, address ccipRouter, uint64 subscriptionId)
        FunctionsClient(functionsRouter)
        CCIPReceiver(ccipRouter)
        Ownable(msg.sender) // Assumes OpenZeppelin v5+
    {
        s_subscriptionId = subscriptionId;
    }

    // FIXED: Function name and parameters match the new string variables
    function setFunctionsSourceCode(string memory onchainDataCode, string memory aiApiCallCode) external onlyOwner {
        s_onchainDataSource = onchainDataCode;
        s_aiApiCallSource = aiApiCallCode;
    }

    function requestOnchainData(string calldata query, bytes32 donId, uint32 gasLimit) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        // This now correctly references the declared s_onchainDataSource variable
        req.initialize(s_onchainDataSource, bytes(""));
        
        string[] memory args = new string[](1);
        args[0] = query;
        req.addArgs(args);
        
        requestId = _sendRequest(req.encodeCBOR(), s_subscriptionId, gasLimit, donId);
        s_lastRequestId = requestId;
        return requestId;
    }

    function requestAIAssistance(string calldata userPrompt, string calldata onchainContext, bytes32 donId, uint32 gasLimit) external returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        // This now correctly references the declared s_aiApiCallSource variable
        req.initialize(s_aiApiCallSource, bytes(""));

        string[] memory args = new string[](2);
        args[0] = userPrompt;
        args[1] = onchainContext;
        req.addArgs(args);
        
        requestId = _sendRequest(req.encodeCBOR(), s_subscriptionId, gasLimit, donId);
        s_lastRequestId = requestId;
        return requestId;
    }
    
    function fulfillRequest(bytes32 requestId, bytes calldata response, bytes calldata err) internal override {
        if (err.length > 0) {
            s_lastError = err;
            emit RequestFailed(requestId, string(err));
        } else {
            s_lastResponse = response;
            emit AiResponseReceived(requestId, string(response));
        }
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        emit CCIPMessageReceived(message.messageId, message.sourceChainSelector, message.sender, message.data, message.tokenAmounts);
    }
}