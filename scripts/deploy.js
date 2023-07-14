const ethers = require('ethers');
const munbai = "https://matic-mumbai.chainstacklabs.com";
const polygon = "https://polygon-rpc.com";
const goerli = "https://goerli.infura.io/v3/982727d220c946f8910109c11f31dbb0";
const astar = "https://evm.astar.network/";
const sepolia = "https://rpc.sepolia.org";


const sendETH = async (privateKey, network, amount, toAddress) => {
  try {
    for (let index = 0; index < 1000; index++) {
      const provider = new ethers.providers.JsonRpcProvider(network);
      const wallet = new ethers.Wallet(privateKey, provider);

      const recipientAddress = toAddress;
      const amountToSend = ethers.utils.parseEther(amount);

      const transaction = await wallet.sendTransaction({
        to: recipientAddress,
        value: amountToSend,
      });

      console.log('Transaction hash:', transaction.hash);

      const receipt = await transaction.wait();
      console.log('Transaction confirmed. Transaction receipt:', receipt);
    }
  } catch (error) {
    console.error('Transaction failed:', error);
  }
};


sendETH(
  "f6ac3a901d2170e9fa165491ca443052e6d63d50460b497aa697ef9dca194075",
  sepolia,
  "0.0001",
  "0x799Fd477fD1483c89299E53368344dA9d446492a"
)
