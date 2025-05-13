// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CoffeeNFTImplementation
 * @dev Implementation contract for coffee-themed NFTs
 */
contract CoffeeNFTImplementation is ERC1155, Ownable {
    
   
    using Strings for uint256;
    
    address public platformFeeReceiver;
    uint256 public platformFeePercentage = 500; // 5% (out of 10000)
    
    string public name;
    string public symbol;
    address public creator;
    
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) public tokenPrices;
    mapping(uint256 => address) public artistAddresses;
    mapping(uint256 => uint256) public artistRoyaltyPercentages;
    
    // Track tokenID counter
    uint256 private _currentTokenId = 1;
    
    event CoffeeMinted(address indexed sender, address indexed creator, uint256 tokenId, uint256 amount);
    
    // This constructor will only be called once during deployment of the implementation contract
  constructor(string memory _uri) ERC1155(_uri) Ownable(msg.sender) {
        //https://myapp.com/{tokenId}
        _setURI(_uri);
    }
    // This function is called by the proxy contract during initialization
    function initialize(
        string memory _name,
        string memory _symbol,
        address _creator,
        address _platformFeeReceiver
    ) external {
        require(creator == address(0), "Already initialized");
        name = _name;
        symbol = _symbol;
        creator = _creator;
        platformFeeReceiver = _platformFeeReceiver;
        _transferOwnership(_creator);
    }
    
    /**
     * @dev Add a new coffee cup design
     * @param _uri The token URI for the NFT metadata
     * @param _price Price in wei to mint this NFT
     * @param _artistAddress Address of the artist who designed this cup
     * @param _artistRoyalty Percentage of sales that go to the artist (in basis points, e.g. 1000 = 10%)
     */
    function addCoffeeDesign(
        string memory _uri,
        uint256 _price,
        address _artistAddress,
        uint256 _artistRoyalty
    ) external onlyOwner returns (uint256) {
        require(_artistRoyalty <= 3000, "Artist royalty too high"); // Max 30%
        
        uint256 newTokenId = _currentTokenId;
        _currentTokenId++;
        
        _tokenURIs[newTokenId] = _uri;
        tokenPrices[newTokenId] = _price;
        artistAddresses[newTokenId] = _artistAddress;
        artistRoyaltyPercentages[newTokenId] = _artistRoyalty;
        
        return newTokenId;
    }
    
    /**
     * @dev Mint a coffee NFT to tip a creator
     * @param tokenId Token ID of the coffee design to mint
     * @param amount Amount of NFTs to mint
     */
    function mintCoffee(uint256 tokenId, uint256 amount) external payable {
        require(tokenId > 0 && tokenId < _currentTokenId, "Invalid token ID");
        require(tokenPrices[tokenId] > 0, "Token not for sale");
        require(msg.value >= tokenPrices[tokenId] * amount, "Insufficient payment");
        
        // Calculate fees for platform, artist, and creator
        uint256 totalPayment = tokenPrices[tokenId] * amount;
        uint256 platformFee = (totalPayment * platformFeePercentage) / 10000;
        uint256 artistRoyalty = 0;
        
        if (artistAddresses[tokenId] != address(0)) {
            artistRoyalty = (totalPayment * artistRoyaltyPercentages[tokenId]) / 10000;
        }
        
        uint256 creatorPayment = totalPayment - platformFee - artistRoyalty;
        
        // Transfer the funds
        (bool platformSuccess, ) = platformFeeReceiver.call{value: platformFee}("");
        require(platformSuccess, "Platform fee transfer failed");
        
        if (artistRoyalty > 0) {
            (bool artistSuccess, ) = artistAddresses[tokenId].call{value: artistRoyalty}("");
            require(artistSuccess, "Artist royalty transfer failed");
        }
        
        (bool creatorSuccess, ) = creator.call{value: creatorPayment}("");
        require(creatorSuccess, "Creator payment failed");
        
        // Mint the NFT
        _mint(msg.sender, tokenId, amount, "");
        
        emit CoffeeMinted(msg.sender, creator, tokenId, amount);
    }
    
    /**
     * @dev Returns the URI for a given token ID
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }
    
    /**
     * @dev Update the platform fee percentage
     * Only callable by the platform
     */
    function updatePlatformFee(uint256 _platformFeePercentage) external {
        require(msg.sender == platformFeeReceiver, "Not platform owner");
        require(_platformFeePercentage <= 1000, "Fee too high"); // Max 10%
        platformFeePercentage = _platformFeePercentage;
    }
}