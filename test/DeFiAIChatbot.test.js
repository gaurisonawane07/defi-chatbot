const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DeFiAICatbotSimplified", function () {
    let defiBot, owner, user1;
    const subId = 123;
    const gasLimit = 300000;

    beforeEach(async function () {
        [owner, user1] = await ethers.getSigners();
        const DeFiAICatbotFactory = await ethers.getContractFactory("DeFiAICatbotSimplified");
        defiBot = await DeFiAICatbotFactory.deploy(subId, gasLimit);
        await defiBot.deployed();
    });

    it("Should allow the owner to simulate a successful fulfillment", async function () {
        const testRequestId = "0x" + "a".repeat(64); // Example request ID
        const testResponse = "This is a test AI response.";

        
        await defiBot.connect(user1).requestAIAssistance("source", "query", "context");
        
        const tx = await defiBot.connect(user1).requestAIAssistance("js-source", "What is staking?", "");
        const receipt = await tx.wait();
        
        const mockRequestId = ethers.utils.formatBytes32String("test1");
        
        
        // Let's assume you've added the test helper function `testFulfill`
        const responseBytes = ethers.utils.defaultAbiCoder.encode(["string"], [testResponse]);
        const errorBytes = ethers.utils.toUtf8Bytes("");

        // We expect the contract to emit our event
        await expect(
            defiBot.connect(owner).testFulfill(mockRequestId, responseBytes, errorBytes)
        ).to.emit(defiBot, "AIResponseReceived")
         .withArgs(mockRequestId, user1.address, testResponse); // Assuming you've set the user for mockRequestId
    });
});