// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract DeFiAICatbotSimplified is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    // --- Configuration Variables ---
    address public immutable i_functionsRouter;
    bytes32 public immutable i_donId;
    uint64 public i_subscriptionId;
    uint32 public i_callbackGasLimit;

    address constant SEPOLIA_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 constant SEPOLIA_DON_ID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // --- State Variables ---
    mapping(bytes32 => address) private s_requestingUser;

    // --- Events ---
    event AIResponseReceived(
        bytes32 indexed requestId,
        address indexed userAddress,
        string responseText
    );

    event OnchainDataReceived(
        bytes32 indexed requestId,
        address indexed userAddress,
        string formattedData
    );

    // --- Constructor ---
    constructor(uint64 subscriptionId, uint32 callbackGasLimit)
        FunctionsClient(SEPOLIA_ROUTER)
        ConfirmedOwner(msg.sender)
    {
        i_functionsRouter = SEPOLIA_ROUTER;
        i_donId = SEPOLIA_DON_ID;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    // --- Functions to Request Chainlink Functions ---

    function requestOnchainData(
        string calldata jsSourceCode,
        string[] calldata jsArgs
    ) external returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(jsSourceCode);
        if (jsArgs.length > 0) req.setArgs(jsArgs);

        requestId = _sendRequest(
            req.encodeCBOR(),
            i_subscriptionId,
            i_callbackGasLimit,
            i_donId
        );

        s_requestingUser[requestId] = msg.sender;
        return requestId;
    }

    function requestAIAssistance(
        string calldata jsSourceCode,
        string calldata userQuery,
        string calldata onchainContext
    ) external returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(jsSourceCode);

        string[] memory args = new string[](2);
        args[0] = userQuery;
        args[1] = onchainContext;
        req.setArgs(args);

        requestId = _sendRequest(
            req.encodeCBOR(),
            i_subscriptionId,
            i_callbackGasLimit,
            i_donId
        );

        s_requestingUser[requestId] = msg.sender;
        return requestId;
    }

    // --- Corrected Callback Function for Chainlink Functions Responses ---

    
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response, // Changed from calldata to memory
        bytes memory err       // Changed from calldata to memory
    ) internal override {
        address user = s_requestingUser[requestId];
        require(user != address(0), "Request not found or already processed.");

        delete s_requestingUser[requestId];

        if (err.length > 0) {
            string memory errorMessage = string(err);
            emit AIResponseReceived(requestId, user, string(abi.encodePacked("Error from Functions: ", errorMessage)));
            return;
        }

        string memory decodedResponse = abi.decode(response, (string));

        emit AIResponseReceived(requestId, user, decodedResponse);
    }

    // --- Admin Function (Owner-only) ---

    function updateSubscriptionId(uint64 newSubscriptionId) external onlyOwner {
        i_subscriptionId = newSubscriptionId;
    }
    function testFulfill(
    bytes32 requestId,
    bytes memory response,
    bytes memory err
) external onlyOwner {
    // This directly calls the internal function we want to test
    fulfillRequest(requestId, response, err);
}
}
