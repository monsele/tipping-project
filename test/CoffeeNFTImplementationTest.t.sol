// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CoffeeNFTImplementation.sol";
import "../src/MintMeACoffeeFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Import Ownable
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // Import ERC20

// Mock USDC token for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        // Constructor
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // USDC uses 6 decimals, but we'll use 18 for simplicity in tests
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}

contract CoffeeNFTImplementationTest is Test {
    CoffeeNFTImplementation public implementation;
    MintMeACoffeeFactory public factory;
    MockUSDC public usdc;
    address public creator;
    address public platformFeeReceiver;
    address public artist1;
    address public artist2;
    address public user1;
    address public user2;

    // Constants for testing
    uint256 constant PRICE_PER_COFFEE = 10 * 10**18; // 10 USDC per coffee
    uint256 constant INITIAL_BALANCE = 1000 * 10**18; // 1000 USDC

    function setUp() public {
        // Deploy the mock USDC token
        usdc = new MockUSDC();

        // Deploy the implementation contract
        implementation = new CoffeeNFTImplementation("https://example.com/{id}");
        
        // Set the USDC token address in the implementation
        implementation.setUsdcToken(address(usdc));
        
        creator = address(0x49abF65f5c9F13Ba55280Ab7E304dDA06cD718cf); // Using a fixed address for creator
        platformFeeReceiver = address(this); // Set the test contract as the fee receiver
        artist1 = address(0x5678Ab9CDEf012345678AB9CDeF012345678Ab9c); // fixed address (checksummed)
        artist2 = address(0x976EA74026E726554dB657fA54763abd0C3a0aa9); // fixed address (checksummed)
        user1 = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720); // fixed
        user2 = address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f); // fixed

        // Deploy the factory contract
        factory = new MintMeACoffeeFactory(address(implementation));

        // Create a coffee contract for the creator via the factory
        address creatorContract = factory.createCoffeeContract("Creator's Coffee", "CCF", creator);
        //change the owner to the creator, because the factory is the owner
        vm.prank(creator);
        Ownable(creatorContract).transferOwnership(creator);
        
        // Set the USDC token address in the creator's contract
        vm.prank(creator);
        CoffeeNFTImplementation(creatorContract).setUsdcToken(address(usdc));

        // Mint USDC to users for testing
        usdc.mint(user1, INITIAL_BALANCE);
        usdc.mint(user2, INITIAL_BALANCE);
    }

    // Helper function to get the creator's contract address
    function getCreatorContract() internal view returns (address) {
        return factory.getCreatorContract(creator);
    }

    function getOwner() public view returns (address) {
        return implementation.owner();
    }

    // Helper function to add a coffee design. Uses the creator as the sender.
    function addCoffeeDesignHelper(
        address _creatorContract,
        string memory _uri,
        uint256 _price,
        address _artistAddress,
        uint256 _artistRoyalty
    ) internal returns (uint256) {
        vm.prank(creator); // Only creator can add design.
        uint256 tokenId =
            CoffeeNFTImplementation(_creatorContract).addCoffeeDesign(_uri, _price, _artistAddress, _artistRoyalty);
        return tokenId;
    }

    // Helper function to mint coffee. Uses user1 as sender
    function mintCoffeeHelper(address _creatorContract, uint256 _tokenId, uint256 _amount) internal {
        // Calculate total cost
        uint256 totalCost = CoffeeNFTImplementation(_creatorContract).tokenPrices(_tokenId) * _amount;
        
        // Approve tokens first
        vm.prank(user1);
        usdc.approve(_creatorContract, totalCost);
        
        // Mint coffee
        vm.prank(user1);
        CoffeeNFTImplementation(_creatorContract).mintCoffee(_tokenId, _amount);
    }

    // --- Implementation Contract Tests ---

    function test_Implementation_Initialize() public {
        // Verify that the implementation contract is initialized correctly
        assertEq(implementation.owner(), address(this), "Implementation owner should be deployer");
        assertEq(implementation.usdcToken(), address(usdc), "USDC token not set correctly");
    }

    function test_Implementation_AddCoffeeDesign() public {
        address creatorContract = getCreatorContract();
        string memory uri = "ipfs://QmSomeHash";
        uint256 price = PRICE_PER_COFFEE;
        uint256 tokenId = addCoffeeDesignHelper(creatorContract, uri, price, artist1, 1000); // 10%

        assertEq(CoffeeNFTImplementation(creatorContract).uri(tokenId), uri, "Incorrect URI");
        assertEq(CoffeeNFTImplementation(creatorContract).tokenPrices(tokenId), price, "Incorrect price");
        assertEq(CoffeeNFTImplementation(creatorContract).artistAddresses(tokenId), artist1, "Incorrect artist address");
        assertEq(CoffeeNFTImplementation(creatorContract).artistRoyaltyPercentages(tokenId), 1000, "Incorrect royalty");
    }

    function test_Implementation_AddCoffeeDesign_RevertsIfRoyaltyTooHigh() public {
        address creatorContract = getCreatorContract();
        vm.expectRevert(bytes("Artist royalty too high"));
        addCoffeeDesignHelper(creatorContract, "ipfs://...", PRICE_PER_COFFEE, artist1, 3001); // 30.01%
    }

    function test_Implementation_MintCoffee() public {
        address creatorContract = getCreatorContract();
        uint256 tokenId = addCoffeeDesignHelper(creatorContract, "ipfs://...", PRICE_PER_COFFEE, artist1, 1000); // 10%
        uint256 amount = 2;
        uint256 totalValue = PRICE_PER_COFFEE * amount;

        // Track initial balances
        uint256 initialCreatorBalance = usdc.balanceOf(creator);
        uint256 initialPlatformBalance = usdc.balanceOf(platformFeeReceiver);
        uint256 initialArtistBalance = usdc.balanceOf(artist1);
        uint256 initialUserBalance = usdc.balanceOf(user1);

        mintCoffeeHelper(creatorContract, tokenId, amount);

        assertEq(CoffeeNFTImplementation(creatorContract).balanceOf(user1, tokenId), amount, "Incorrect amount minted");

        uint256 expectedPlatformFee = (totalValue * 500) / 10000; // 5%
        uint256 expectedArtistRoyalty = (totalValue * 1000) / 10000; // 10%
        uint256 expectedCreatorPayment = totalValue - expectedPlatformFee - expectedArtistRoyalty;

        // Check USDC balances after mint
        assertEq(usdc.balanceOf(creator), initialCreatorBalance + expectedCreatorPayment, "Incorrect creator payment");
        assertEq(usdc.balanceOf(platformFeeReceiver), initialPlatformBalance + expectedPlatformFee, "Incorrect platform fee");
        assertEq(usdc.balanceOf(artist1), initialArtistBalance + expectedArtistRoyalty, "Incorrect artist royalty");
        assertEq(usdc.balanceOf(user1), initialUserBalance - totalValue, "Incorrect user balance reduction");
    }

    function test_Implementation_MintCoffee_RevertsIfInvalidTokenId() public {
        address creatorContract = getCreatorContract();
        vm.expectRevert(bytes("Invalid token ID"));
        mintCoffeeHelper(creatorContract, 999, 1); // 999 is invalid
    }

    function test_Implementation_MintCoffee_RevertsIfTokenNotForSale() public {
        address creatorContract = getCreatorContract();
        uint256 tokenId = addCoffeeDesignHelper(creatorContract, "ipfs://...", 0, artist1, 1000); // Price 0
        vm.expectRevert(bytes("Token not for sale"));
        mintCoffeeHelper(creatorContract, tokenId, 1);
    }

    function test_Implementation_MintCoffee_RevertsIfInsufficientApproval() public {
        address creatorContract = getCreatorContract();
        uint256 tokenId = addCoffeeDesignHelper(creatorContract, "ipfs://...", PRICE_PER_COFFEE, artist1, 1000);
        
        // Approve less than required
        uint256 insufficientAmount = PRICE_PER_COFFEE / 2;
        vm.prank(user1);
        usdc.approve(creatorContract, insufficientAmount);
        
        // Should revert on transferFrom within mintCoffee
        vm.prank(user1);
        vm.expectRevert();  // ERC20 reverts with a standard error
        CoffeeNFTImplementation(creatorContract).mintCoffee(tokenId, 1);
    }

    function test_Implementation_UpdatePlatformFee() public {
        address creatorContract = getCreatorContract();
        vm.prank(address(this)); // Only platformFeeReceiver can call
        CoffeeNFTImplementation(creatorContract).updatePlatformFee(100); // 1%
        assertEq(CoffeeNFTImplementation(creatorContract).platformFeePercentage(), 100, "Fee not updated");
    }

    function test_Implementation_UpdatePlatformFee_RevertsIfNotPlatformFeeReceiver() public {
        address creatorContract = getCreatorContract();
        vm.prank(user1); // Not platformFeeReceiver
        vm.expectRevert(bytes("Not platform owner"));
        CoffeeNFTImplementation(creatorContract).updatePlatformFee(100);
    }

    function test_Implementation_UpdatePlatformFee_RevertsIfFeeTooHigh() public {
        address creatorContract = getCreatorContract();
        vm.prank(address(this));
        vm.expectRevert(bytes("Fee too high"));
        CoffeeNFTImplementation(creatorContract).updatePlatformFee(1001); // > 10%
    }

    function test_Implementation_SetUsdcToken() public {
        address creatorContract = getCreatorContract();
        address newUsdcToken = address(0x1234567890123456789012345678901234567890);
        
        vm.prank(creator); // Only owner can set USDC token
        CoffeeNFTImplementation(creatorContract).setUsdcToken(newUsdcToken);
        
        assertEq(CoffeeNFTImplementation(creatorContract).usdcToken(), newUsdcToken, "USDC token not updated");
    }

    function test_Implementation_SetUsdcToken_RevertsIfNotOwner() public {
        address creatorContract = getCreatorContract();
        address newUsdcToken = address(0x1234567890123456789012345678901234567890);
        
        vm.prank(user1); // Not owner
        vm.expectRevert("Ownable: caller is not the owner");
        CoffeeNFTImplementation(creatorContract).setUsdcToken(newUsdcToken);
    }

    // --- Factory Contract Tests ---

    function test_Factory_CreateCoffeeContract() public {
        address creator2 = address(0x6789012345678901234567890123456789012345);
        address newContract = factory.createCoffeeContract("Creator2 Coffee", "C2C", creator2);
        assertNotEq(newContract, address(0), "Contract not created");
        assertEq(factory.creatorContracts(creator2), newContract, "Creator contract not mapped");
        vm.prank(creator2);
        assertEq(Ownable(newContract).owner(), creator2, "Owner is not creator"); // Check owner via the interface
    }

    function test_Factory_CreateCoffeeContract_EmitsEvent() public {
        address creator2 = address(0x6789012345678901234567890123456789012345);
        vm.expectEmit(true, true, false, true, address(factory)); //check event
        factory.createCoffeeContract("Creator2 Coffee", "C2C", creator2);
    }

    function test_Factory_CreateCoffeeContract_RevertsIfCreatorHasContract() public {
        vm.expectRevert(bytes("Creator already has a contract"));
        factory.createCoffeeContract("Duplicate Coffee", "DUP", creator);
    }

    function test_Factory_CreateCoffeeContract_OnlyOwnerOrCreator() public {
        address creator3 = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        vm.prank(user1); // Not owner or creator3
        vm.expectRevert(bytes("Not authorized to create contract"));
        factory.createCoffeeContract("Creator3 Coffee", "C3C", creator3);

        // Should succeed when called by the creator
        vm.prank(creator3);
        address creator3Contract = factory.createCoffeeContract("Creator3 Coffee", "C3C", creator3);
        assertNotEq(creator3Contract, address(0), "Contract not created by creator");
    }

    function test_Factory_UpdateImplementation() public {
        address newImplementation = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        vm.prank(getOwner());
        factory.updateImplementation(newImplementation);
        assertEq(factory.implementationContract(), newImplementation, "Implementation contract not updated");
    }

    function test_Factory_UpdateImplementation_RevertsIfZeroAddress() public {
        vm.prank(getOwner());
        vm.expectRevert(bytes("Invalid implementation address"));
        factory.updateImplementation(address(0));
    }

    function test_Factory_UpdatePlatformFeeReceiver() public {
        address newPlatformFeeReceiver = address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65);
        vm.prank(getOwner());
        factory.updatePlatformFeeReceiver(newPlatformFeeReceiver);
        assertEq(factory.platformFeeReceiver(), newPlatformFeeReceiver, "Platform fee receiver not updated");
    }

    function test_Factory_UpdatePlatformFeeReceiver_RevertsIfZeroAddress() public {
        vm.prank(getOwner());
        vm.expectRevert(bytes("Invalid platform fee receiver"));
        factory.updatePlatformFeeReceiver(address(0));
    }

    function test_Factory_GetContractCount() public {
        uint256 initialCount = factory.getContractCount();
        factory.createCoffeeContract("Creator2 Coffee", "C2C", address(0x6789012345678901234567890123456789012345));
        uint256 newCount = factory.getContractCount();
        assertEq(newCount, initialCount + 1, "Contract count not incremented");
    }

    function test_Factory_GetCreatorContract() public {
        address creatorContract = factory.getCreatorContract(creator);
        assertNotEq(creatorContract, address(0), "Should return a valid address");
        // Further check that the returned address matches the deployed contract.
        // This is already checked in setUp, but adding here for completeness
        assertEq(factory.creatorContracts(creator), creatorContract, "getCreatorContract returns incorrect address");
    }
}
