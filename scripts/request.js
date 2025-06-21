// scripts/request.js

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");
require('dotenv').config();

async function main() {
    
    const contractAddress = "0x081c159922a6382f68Cf8D20650654f451C847C1";
    
    
   
    const privateKey = process.env.PRIVATE_KEY;
    const rpcUrl = process.env.RPC_URL;

    if (!privateKey || !rpcUrl) {
        throw new Error("Missing environment variables.");
    }

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const chatbotContract = await ethers.getContractAt("DeFiAICatbotSimplified", contractAddress, wallet);

    // --- Prepare and Send the Request ---
    console.log(`\n--- Interacting with contract at ${contractAddress} ---`);
    const aiRequestSourceCodePath = path.resolve(__dirname, "../chainlink-functions/ai-request.js");
    const aiSourceCode = fs.readFileSync(aiRequestSourceCodePath, "utf8");
    const userQuery = "What are the risks of impermanent loss in DeFi?";
    const onchainContext = "The user is a beginner.";

    console.log(`Sending AI assistance request for query: "${userQuery}"`);
    
    const requestTxAI = await chatbotContract.requestAIAssistance(aiSourceCode, userQuery, onchainContext);
    const receiptAI = await requestTxAI.wait(1);

    const requestSentEvent = receiptAI.logs.find(log => log.fragment && log.fragment.name === 'RequestSent');
    const requestIdAI = requestSentEvent.args.id;
    
    console.log(`✅ Request sent! Request ID: ${requestIdAI}`);
    console.log(`To view request status, visit: https://functions.chain.link/sepolia/${contractAddress}`);

    console.log(`\n--- Waiting for Chainlink Functions fulfillment... ---`);
    const aiFilter = chatbotContract.filters.AIResponseReceived(requestIdAI);
    
    
    chatbotContract.once(aiFilter, (requestId, userAddress, responseText, event) => {
        console.log("\n--- AI Assistance Request Fulfilled! ---");
        
        console.log(`Request ID: ${event.args.requestId}`);
        console.log(`User Address: ${event.args.userAddress}`);
        console.log(`AI Response: ${event.args.responseText}`);
        process.exit(0);
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});