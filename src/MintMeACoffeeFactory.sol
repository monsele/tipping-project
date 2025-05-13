// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICoffeeNFT {
    function initialize(
        string memory _name,
        string memory _symbol,
        address _creator,
        address _platformFeeReceiver
    ) external;
}

/**
 * @title MintMeACoffeeFactory
 * @dev Factory contract for deploying coffee NFT collection contracts
 */
contract MintMeACoffeeFactory is Ownable {

 
    using Clones for address;
    
    // Implementation contract address that all proxies will point to
    address public implementationContract;
    
    // Platform fee receiver address
    address public platformFeeReceiver;
    
    // Mapping from creator address to their coffee NFT contract
    mapping(address => address) public creatorContracts;
    
    // Array to store all deployed contracts
    address[] public allContracts;
    
    event ContractCreated(address indexed creator, address contractAddress);
    
    constructor(address _implementationContract) Ownable(msg.sender) {
        implementationContract = _implementationContract;
        platformFeeReceiver = msg.sender;
    }
    
    /**
     * @dev Deploy a new coffee NFT contract for a creator
     * @param _name Name of the NFT collection
     * @param _symbol Symbol of the NFT collection
     * @param _creator Address of the creator
     */
    function createCoffeeContract(
        string memory _name,
        string memory _symbol,
        address _creator
    ) external returns (address) {
        // Allow either the platform or the creator themselves to create a contract
        require(
            msg.sender == owner() || msg.sender == _creator,
            "Not authorized to create contract"
        );
        
        // Check if creator already has a contract
        require(creatorContracts[_creator] == address(0), "Creator already has a contract");
        
        // Deploy a minimal proxy contract
        address newContract = implementationContract.clone();
        
        // Initialize the proxy contract
        ICoffeeNFT(newContract).initialize(
            _name,
            _symbol,
            _creator,
            platformFeeReceiver
        );
        
        // Store the new contract address
        creatorContracts[_creator] = newContract;
        allContracts.push(newContract);
        
        emit ContractCreated(_creator, newContract);
        return newContract;
    }
    
    /**
     * @dev Update the implementation contract address
     * @param _implementationContract New implementation contract address
     */
    function updateImplementation(address _implementationContract) external onlyOwner {
        require(_implementationContract != address(0), "Invalid implementation address");
        implementationContract = _implementationContract;
    }
    
    /**
     * @dev Update the platform fee receiver address
     * @param _platformFeeReceiver New platform fee receiver address
     */
    function updatePlatformFeeReceiver(address _platformFeeReceiver) external onlyOwner {
        require(_platformFeeReceiver != address(0), "Invalid platform fee receiver");
        platformFeeReceiver = _platformFeeReceiver;
    }
    
    /**
     * @dev Get the total number of deployed contracts
     */
    function getContractCount() external view returns (uint256) {
        return allContracts.length;
    }
    
    /**
     * @dev Get the contract address for a creator
     * @param _creator Creator address
     */
    function getCreatorContract(address _creator) external view returns (address) {
        return creatorContracts[_creator];
    }
}