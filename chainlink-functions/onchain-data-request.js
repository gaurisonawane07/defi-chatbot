// This script fetches a user's ERC20 token balance from the blockchain.
// It requires one secret: `sepoliaRpcUrl` for a Sepolia RPC endpoint.
// It takes two arguments: args[0] is the user's wallet address, args[1] is the ERC20 token contract address.

// Check if all necessary arguments and secrets are provided
if (!secrets.sepoliaRpcUrl) {
  throw Error("Sepolia RPC URL is not set in secrets.");
}
if (!args[0] || !args[1]) {
  throw Error("User address and token address are required as arguments.");
}

const userAddress = args[0];
const tokenAddress = args[1];

// Initialize an Ethers.js provider
const provider = new ethers.providers.JsonRpcProvider(secrets.sepoliaRpcUrl);

// The minimal ABI required to get balance and decimals
const erc20Abi = [
  "function balanceOf(address owner) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

// Create a contract instance
const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, provider);

// Fetch the balance, decimals, and symbol in parallel
const [balance, decimals, symbol] = await Promise.all([
  tokenContract.balanceOf(userAddress),
  tokenContract.decimals(),
  tokenContract.symbol(),
]);

// Format the balance from its raw BigNumber form to a human-readable string
const formattedBalance = ethers.utils.formatUnits(balance, decimals);

// Construct the result string to be returned to the smart contract
const result = `The balance of ${symbol} for address ${userAddress} is: ${formattedBalance}.`;

console.log(result);

// Return the result as a string, encoded for the smart contract
return Functions.encodeString(result);