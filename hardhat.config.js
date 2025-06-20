require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); 

module.exports = {
  solidity: "0.8.19", 


  networks: {
    sepolia: {
      url: process.env.RPC_URL , 
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111, 
      timeout: 60000,
      
    },
   
  },
   etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY, 
    },
  },

 
};
