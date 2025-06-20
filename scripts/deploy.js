// scripts/deploy.js

const { ethers } = require("hardhat");
const { SubscriptionManager } = require("@chainlink/functions-toolkit");
const ethers5 = require("ethers-v5");
require('dotenv').config();

async function main() {
  
    const privateKey = process.env.PRIVATE_KEY;
    const rpcUrl = process.env.RPC_URL;
    const subscriptionId = process.env.FUNCTIONS_SUBSCRIPTION_ID;

    if (!privateKey || !rpcUrl || !subscriptionId) {
        throw new Error("Missing environment variables.");
    }

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    
   
    const provider5 = new ethers5.providers.JsonRpcProvider(rpcUrl);
    const signer5 = new ethers5.Wallet(privateKey, provider5);
    
    const routerAddress = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
    const linkTokenAddress = "0x779877A7B0D6E86035Edf2681E6574Ee7Fdf50c5";
    const callbackGasLimit = 300000;

    console.log("\n--- Deploying Contract ---");
    const DeFiAICatbotSimplifiedFactory = await ethers.getContractFactory("DeFiAICatbotSimplified");
    const chatbotContract = await DeFiAICatbotSimplifiedFactory.deploy(subscriptionId, callbackGasLimit);
    await chatbotContract.waitForDeployment();
    const contractAddress = await chatbotContract.getAddress();
    console.log(`✅ Contract deployed to: ${contractAddress}`);
    console.log(`Now adding it as a new consumer to subscription ${subscriptionId}...`);

    
    const subManager = new SubscriptionManager({ signer: signer5, linkTokenAddress, functionsRouterAddress: routerAddress });
    await subManager.initialize();

    const addConsumerTx = await subManager.addConsumer({
        subscriptionId: parseInt(subscriptionId),
        consumerAddress: contractAddress,
    });
    console.log(`✅ Successfully added consumer. Transaction hash: ${addConsumerTx.transactionHash}`);
    console.log(`\nDeployment and configuration complete. You can now use the 'request.js' script with the address: ${contractAddress}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});