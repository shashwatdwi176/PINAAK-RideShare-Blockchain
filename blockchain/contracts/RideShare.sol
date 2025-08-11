// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This is the core smart contract for our decentralized ridesharing application.
// It manages the state of rides, payments, and ratings between riders and drivers.
contract RideShare {
    // A struct to represent a single ride.
    struct Ride {
        address rider;
        address driver;
        uint256 fare;
        uint256 timestamp;
        uint256 status; // 0: Requested, 1: Accepted, 2: Completed, 3: Cancelled
        string pickupLocation;
        string dropoffLocation;
    }

    // A mapping to store all rides, indexed by a unique ride ID.
    mapping(uint256 => Ride) public rides;

    // Keep track of the total number of rides created. This will also serve as our ride ID.
    uint256 public nextRideId;

    // Events to notify the frontend and backend of changes on the blockchain.
    event RideRequested(uint256 indexed rideId, address indexed rider, string pickup, string dropoff, uint256 fare);
    event RideAccepted(uint256 indexed rideId, address indexed driver);
    event RideCompleted(uint256 indexed rideId, address indexed rider, address indexed driver);
    event RideCancelled(uint256 indexed rideId);

    // This function allows a rider to request a new ride.
    // The fare is sent with the transaction and held in escrow by the contract.
    function requestRide(
        string memory _pickupLocation,
        string memory _dropoffLocation,
        uint256 _fare
    ) public payable {
        // The value sent with the transaction must be exactly the fare.
        require(msg.value == _fare, "Fare must match the sent value.");

        uint256 rideId = nextRideId;
        rides[rideId] = Ride({
            rider: msg.sender,
            driver: address(0), // Driver is not yet assigned.
            fare: _fare,
            timestamp: block.timestamp,
            status: 0, // Requested
            pickupLocation: _pickupLocation,
            dropoffLocation: _dropoffLocation
        });
        
        nextRideId++;

        emit RideRequested(rideId, msg.sender, _pickupLocation, _dropoffLocation, _fare);
    }

    // This function allows a driver to accept a requested ride.
    function acceptRide(uint256 _rideId) public {
        // Ensure the ride exists and is in the 'Requested' state.
        require(rides[_rideId].rider != address(0), "Ride does not exist.");
        require(rides[_rideId].status == 0, "Ride is not available to be accepted.");
        
        rides[_rideId].driver = msg.sender;
        rides[_rideId].status = 1; // Accepted
        
        emit RideAccepted(_rideId, msg.sender);
    }

    // This function is called by the driver to complete the ride and receive payment.
    function completeRide(uint256 _rideId) public {
        // Ensure the ride exists, is in the 'Accepted' state, and the caller is the assigned driver.
        require(rides[_rideId].driver != address(0), "Ride does not exist.");
        require(rides[_rideId].status == 1, "Ride is not in progress.");
        require(rides[_rideId].driver == msg.sender, "Only the assigned driver can complete the ride.");
        
        rides[_rideId].status = 2; // Completed

        // Transfer the fare from the contract's balance to the driver.
        (bool success, ) = payable(msg.sender).call{value: rides[_rideId].fare}("");
        require(success, "Failed to send fare to driver.");

        emit RideCompleted(_rideId, rides[_rideId].rider, rides[_rideId].driver);
    }

    // This function allows either the rider or driver to cancel a ride.
    function cancelRide(uint256 _rideId) public {
        // Ensure the ride exists and is not already completed or cancelled.
        require(rides[_rideId].rider != address(0), "Ride does not exist.");
        require(rides[_rideId].status < 2, "Cannot cancel a completed or already cancelled ride.");
        
        address rider = rides[_rideId].rider;
        uint256 fare = rides[_rideId].fare;

        rides[_rideId].status = 3; // Cancelled
        
        // Return the escrowed funds to the rider if the fare was paid.
        if (fare > 0) {
             (bool success, ) = payable(rider).call{value: fare}("");
             require(success, "Failed to refund rider.");
        }

        emit RideCancelled(_rideId);
    }

    // A function to get the details of a specific ride.
    function getRide(uint256 _rideId) public view returns (
        address, // rider
        address, // driver
        uint256, // fare
        uint256, // timestamp
        uint256, // status
        string memory, // pickupLocation
        string memory // dropoffLocation
    ) {
        require(rides[_rideId].rider != address(0), "Ride does not exist.");
        Ride memory ride = rides[_rideId];
        return (
            ride.rider,
            ride.driver,
            ride.fare,
            ride.timestamp,
            ride.status,
            ride.pickupLocation,
            ride.dropoffLocation
        );
    }
}
