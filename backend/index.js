// This file acts as the backend service, connecting our React frontend to the blockchain.

// Import necessary libraries
const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');
const dotenv = require('dotenv');

// Load environment variables from .env file
dotenv.config();

// Get smart contract details from environment variables
const contractAddress = process.env.CONTRACT_ADDRESS;
const contractAbi = JSON.parse(process.env.CONTRACT_ABI);

// Setup Express app
const app = express();
const port = 4000;

// Middleware
app.use(cors()); // Allow cross-origin requests from our React app
app.use(express.json()); // Enable parsing of JSON body in requests

// A mock provider for a local Hardhat network.
// In a production environment, you would connect to a real network like Sepolia.
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545/');

// A mock wallet for interacting with the contract.
// This would be a real user's wallet in a live application.
// For now, we use a test account from our Hardhat network.
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Create a contract instance to interact with the smart contract
const rideShareContract = new ethers.Contract(contractAddress, contractAbi, wallet);

// --- API Endpoints ---

// Endpoint for a rider to request a ride
app.post('/api/rideshare/request-ride', async (req, res) => {
  try {
    const { pickupLocation, dropoffLocation, fare } = req.body;
    
    // Convert the fare from ETH to Wei (the smallest unit of ETH)
    const fareInWei = ethers.parseEther(fare.toString());

    // Call the `requestRide` function on the smart contract
    const tx = await rideShareContract.requestRide(pickupLocation, dropoffLocation, {
      value: fareInWei, // Send the fare along with the transaction
    });

    // Wait for the transaction to be mined and confirmed
    await tx.wait();

    // Respond with the transaction hash to the frontend
    res.status(200).json({ transactionHash: tx.hash });
  } catch (error) {
    console.error('Error requesting ride:', error);
    res.status(500).json({ error: 'Failed to request ride.' });
  }
});

// Endpoint to get details for a specific ride
app.get('/api/rideshare/ride/:rideId', async (req, res) => {
  try {
    const { rideId } = req.params;
    
    // Call the `rides` mapping on the smart contract to get ride details
    const ride = await rideShareContract.rides(rideId);

    // Format the response for the frontend
    const formattedRide = {
      rider: ride[0],
      fare: ethers.formatEther(ride[1]), // Convert Wei back to ETH for display
      pickupLocation: ride[2],
      dropoffLocation: ride[3],
      driver: ride[4],
      status: ride[5],
    };

    res.status(200).json(formattedRide);
  } catch (error) {
    console.error('Error fetching ride details:', error);
    res.status(500).json({ error: 'Failed to fetch ride details.' });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Backend service listening at http://localhost:${port}`);
});
