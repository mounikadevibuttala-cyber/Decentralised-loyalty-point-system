// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralised Loyalty Point System
 * @dev A smart contract for managing loyalty points across multiple merchants
 * @author Your Name
 */
contract DecentralisedLoyaltyPointSystem {
    
    // State variables
    address public owner;
    uint256 public totalSupply;
    uint256 public nextMerchantId;
    
    // Structs
    struct Customer {
        uint256 totalPoints;
        bool isActive;
        uint256 joinDate;
    }
    
    struct Merchant {
        address merchantAddress;
        string name;
        bool isActive;
        uint256 pointsIssued;
        uint256 pointsRedeemed;
    }
    
    // Mappings
    mapping(address => Customer) public customers;
    mapping(uint256 => Merchant) public merchants;
    mapping(address => uint256) public merchantIds;
    mapping(address => mapping(uint256 => uint256)) public customerPointsByMerchant;
    
    // Events
    event CustomerRegistered(address indexed customer, uint256 timestamp);
    event MerchantRegistered(uint256 indexed merchantId, address indexed merchant, string name);
    event PointsAwarded(address indexed customer, uint256 indexed merchantId, uint256 points);
    event PointsRedeemed(address indexed customer, uint256 indexed merchantId, uint256 points);
    event PointsTransferred(address indexed from, address indexed to, uint256 points);
    event MerchantStatusToggled(uint256 indexed merchantId, bool isActive);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyActiveMerchant() {
        uint256 merchantId = merchantIds[msg.sender];
        require(merchantId != 0, "Not a registered merchant");
        require(merchants[merchantId].isActive, "Merchant not active");
        _;
    }
    
    modifier onlyActiveCustomer() {
        require(customers[msg.sender].isActive, "Customer not registered or inactive");
        _;
    }
    
    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }
    
    modifier validMerchant(uint256 merchantId) {
        require(merchantId > 0 && merchantId < nextMerchantId, "Invalid merchant ID");
        require(merchants[merchantId].isActive, "Merchant not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextMerchantId = 1;
    }
    
    /**
     * @dev Core Function 1: Award Points to Customer
     * @param customer Address of the customer receiving points
     * @param points Number of points to award
     */
    function awardPoints(address customer, uint256 points) external onlyActiveMerchant validAddress(customer) {
        require(points > 0, "Points must be greater than 0");
        
        // Register customer if not already registered
        if (!customers[customer].isActive) {
            customers[customer] = Customer({
                totalPoints: 0,
                isActive: true,
                joinDate: block.timestamp
            });
            emit CustomerRegistered(customer, block.timestamp);
        }
        
        uint256 merchantId = merchantIds[msg.sender];
        
        // Update customer points
        customers[customer].totalPoints += points;
        customerPointsByMerchant[customer][merchantId] += points;
        
        // Update merchant stats
        merchants[merchantId].pointsIssued += points;
        
        // Update total supply
        totalSupply += points;
        
        emit PointsAwarded(customer, merchantId, points);
    }
    
    /**
     * @dev Core Function 2: Redeem Points
     * @param merchantId ID of the merchant where points are being redeemed
     * @param points Number of points to redeem
     */
    function redeemPoints(uint256 merchantId, uint256 points) external onlyActiveCustomer validMerchant(merchantId) {
        require(points > 0, "Points must be greater than 0");
        require(customers[msg.sender].totalPoints >= points, "Insufficient total points");
        require(customerPointsByMerchant[msg.sender][merchantId] >= points, "Insufficient points with this merchant");
        
        // Deduct points
        customers[msg.sender].totalPoints -= points;
        customerPointsByMerchant[msg.sender][merchantId] -= points;
        
        // Update merchant stats
        merchants[merchantId].pointsRedeemed += points;
        
        // Update total supply
        totalSupply -= points;
        
        emit PointsRedeemed(msg.sender, merchantId, points);
    }
    
    /**
     * @dev Core Function 3: Transfer Points Between Customers
     * @param to Address of the recipient customer
     * @param points Number of points to transfer
     */
    function transferPoints(address to, uint256 points) external onlyActiveCustomer validAddress(to) {
        require(to != msg.sender, "Cannot transfer to self");
        require(points > 0, "Points must be greater than 0");
        require(customers[msg.sender].totalPoints >= points, "Insufficient points");
        
        // Register recipient if not already registered
        if (!customers[to].isActive) {
            customers[to] = Customer({
                totalPoints: 0,
                isActive: true,
                joinDate: block.timestamp
            });
            emit CustomerRegistered(to, block.timestamp);
        }
        
        // Transfer points
        customers[msg.sender].totalPoints -= points;
        customers[to].totalPoints += points;
        
        emit PointsTransferred(msg.sender, to, points);
    }
    
    // Administrative functions
    
    /**
     * @dev Register a new merchant
     * @param merchantAddress Address of the merchant
     * @param name Name of the merchant
     */
    function registerMerchant(address merchantAddress, string memory name) external onlyOwner validAddress(merchantAddress) {
        require(merchantIds[merchantAddress] == 0, "Merchant already registered");
        require(bytes(name).length > 0, "Merchant name cannot be empty");
        
        merchants[nextMerchantId] = Merchant({
            merchantAddress: merchantAddress,
            name: name,
            isActive: true,
            pointsIssued: 0,
            pointsRedeemed: 0
        });
        
        merchantIds[merchantAddress] = nextMerchantId;
        
        emit MerchantRegistered(nextMerchantId, merchantAddress, name);
        nextMerchantId++;
    }
    
    /**
     * @dev Toggle merchant active status (only owner)
     * @param merchantId ID of the merchant
     */
    function toggleMerchantStatus(uint256 merchantId) external onlyOwner {
        require(merchantId > 0 && merchantId < nextMerchantId, "Invalid merchant ID");
        merchants[merchantId].isActive = !merchants[merchantId].isActive;
        emit MerchantStatusToggled(merchantId, merchants[merchantId].isActive);
    }
    
    /**
     * @dev Transfer ownership (only owner)
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner validAddress(newOwner) {
        require(newOwner != owner, "New owner must be different from current owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Deactivate customer (only owner - for emergency situations)
     * @param customer Address of the customer to deactivate
     */
    function deactivateCustomer(address customer) external onlyOwner validAddress(customer) {
        require(customers[customer].isActive, "Customer is not active");
        customers[customer].isActive = false;
    }
    
    /**
     * @dev Reactivate customer (only owner)
     * @param customer Address of the customer to reactivate
     */
    function reactivateCustomer(address customer) external onlyOwner validAddress(customer) {
        require(customers[customer].joinDate > 0, "Customer never existed");
        customers[customer].isActive = true;
    }
    
    // View functions
    
    /**
     * @dev Get customer information
     * @param customer Address of the customer
     */
    function getCustomerInfo(address customer) external view returns (
        uint256 totalPoints,
        bool isActive,
        uint256 joinDate
    ) {
        Customer memory c = customers[customer];
        return (c.totalPoints, c.isActive, c.joinDate);
    }
    
    /**
     * @dev Get customer points with specific merchant
     * @param customer Address of the customer
     * @param merchantId ID of the merchant
     */
    function getCustomerPointsWithMerchant(address customer, uint256 merchantId) 
        external view returns (uint256) {
        return customerPointsByMerchant[customer][merchantId];
    }
    
    /**
     * @dev Get merchant statistics
     * @param merchantId ID of the merchant
     */
    function getMerchantStats(uint256 merchantId) external view returns (
        address merchantAddress,
        string memory name,
        bool isActive,
        uint256 pointsIssued,
        uint256 pointsRedeemed
    ) {
        Merchant memory m = merchants[merchantId];
        return (m.merchantAddress, m.name, m.isActive, m.pointsIssued, m.pointsRedeemed);
    }
    
    /**
     * @dev Get merchant ID by address
     * @param merchantAddress Address of the merchant
     */
    function getMerchantId(address merchantAddress) external view returns (uint256) {
        return merchantIds[merchantAddress];
    }
    
    /**
     * @dev Get contract statistics
     */
    function getContractStats() external view returns (
        uint256 _totalSupply,
        uint256 _totalMerchants,
        address _owner
    ) {
        return (totalSupply, nextMerchantId - 1, owner);
    }
    
    /**
     * @dev Check if address is a registered and active merchant
     * @param merchantAddress Address to check
     */
    function isActiveMerchant(address merchantAddress) external view returns (bool) {
        uint256 merchantId = merchantIds[merchantAddress];
        return merchantId != 0 && merchants[merchantId].isActive;
    }
    
    /**
     * @dev Check if address is a registered and active customer
     * @param customer Address to check
     */
    function isActiveCustomer(address customer) external view returns (bool) {
        return customers[customer].isActive;
    }
}
