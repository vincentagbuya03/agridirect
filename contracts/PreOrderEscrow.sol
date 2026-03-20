// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PreOrderEscrow
 * @dev Smart contract for AgriDirect pre-order payments
 * Holds USDC funds in escrow until delivery is confirmed
 */

contract PreOrderEscrow is ReentrancyGuard, Ownable {
    // USDC on Polygon: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
    IERC20 public usdc;

    enum EscrowStatus {
        FUNDED,        // Buyer deposited, waiting for delivery
        DELIVERED,     // Buyer confirms delivery
        RELEASED,      // Farmer received payment
        DISPUTED,      // Payment disputed
        REFUNDED       // Refund issued
    }

    struct Escrow {
        address buyer;
        address seller;
        uint256 amount;
        string orderId;    // Linked to AgriDirect order
        EscrowStatus status;
        uint256 deliveryDeadline;
        uint256 createdAt;
        uint256 releasedAt;
    }

    // escrowId -> Escrow details
    mapping(bytes32 => Escrow) public escrows;

    // Track all escrow IDs
    bytes32[] public escrowIds;

    // Fees
    uint256 public platformFeePercent = 2; // 2% platform fee
    address public feeRecipient;

    event EscrowCreated(
        bytes32 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        string orderId
    );

    event DeliveryConfirmed(bytes32 indexed escrowId, address indexed buyer);

    event PaymentReleased(
        bytes32 indexed escrowId,
        address indexed seller,
        uint256 amount,
        uint256 fee
    );

    event EscrowDisputed(bytes32 indexed escrowId, string reason);

    event PaymentRefunded(bytes32 indexed escrowId, address indexed buyer);

    constructor(address _usdc, address _feeRecipient) {
        usdc = IERC20(_usdc);
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Create new escrow for pre-order
     * @param _buyer Customer wallet address
     * @param _seller Farmer wallet address
     * @param _amount Amount in USDC (wei)
     * @param _orderId AgriDirect order ID
     * @param _deliveryDays Days until delivery deadline
     */
    function createEscrow(
        address _buyer,
        address _seller,
        uint256 _amount,
        string memory _orderId,
        uint256 _deliveryDays
    ) external nonReentrant returns (bytes32) {
        require(_buyer != address(0), "Invalid buyer");
        require(_seller != address(0), "Invalid seller");
        require(_amount > 0, "Amount must be > 0");
        require(_deliveryDays > 0, "Delivery days must be > 0");

        // Transfer USDC from buyer to contract
        require(
            usdc.transferFrom(_buyer, address(this), _amount),
            "Transfer failed"
        );

        // Generate escrow ID
        bytes32 escrowId = keccak256(
            abi.encodePacked(_buyer, _seller, _orderId, block.timestamp)
        );

        // Create escrow
        escrows[escrowId] = Escrow({
            buyer: _buyer,
            seller: _seller,
            amount: _amount,
            orderId: _orderId,
            status: EscrowStatus.FUNDED,
            deliveryDeadline: block.timestamp + (_deliveryDays * 1 days),
            createdAt: block.timestamp,
            releasedAt: 0
        });

        escrowIds.push(escrowId);

        emit EscrowCreated(escrowId, _buyer, _seller, _amount, _orderId);

        return escrowId;
    }

    /**
     * @dev Buyer confirms delivery received
     */
    function confirmDelivery(bytes32 _escrowId) external nonReentrant {
        Escrow storage escrow = escrows[_escrowId];
        require(escrow.buyer == msg.sender, "Only buyer can confirm");
        require(escrow.status == EscrowStatus.FUNDED, "Invalid status");

        escrow.status = EscrowStatus.DELIVERED;

        emit DeliveryConfirmed(_escrowId, msg.sender);
    }

    /**
     * @dev Release funds to farmer
     * Can be called after delivery confirmation or after deadline
     */
    function releaseFunds(bytes32 _escrowId) external nonReentrant {
        Escrow storage escrow = escrows[_escrowId];
        require(
            msg.sender == owner() || msg.sender == escrow.seller,
            "Not authorized"
        );
        require(
            escrow.status == EscrowStatus.DELIVERED ||
                block.timestamp > escrow.deliveryDeadline,
            "Cannot release yet"
        );

        // Calculate fee
        uint256 fee = (escrow.amount * platformFeePercent) / 100;
        uint256 sellerAmount = escrow.amount - fee;

        // Update status
        escrow.status = EscrowStatus.RELEASED;
        escrow.releasedAt = block.timestamp;

        // Transfer to seller
        require(usdc.transfer(escrow.seller, sellerAmount), "Seller transfer failed");

        // Transfer fee to platform
        if (fee > 0) {
            require(usdc.transfer(feeRecipient, fee), "Fee transfer failed");
        }

        emit PaymentReleased(_escrowId, escrow.seller, sellerAmount, fee);
    }

    /**
     * @dev Refund to buyer (only before delivery confirmed)
     */
    function refundToBuyer(bytes32 _escrowId, string memory _reason)
        external
        nonReentrant
    {
        Escrow storage escrow = escrows[_escrowId];
        require(
            msg.sender == owner() || msg.sender == escrow.buyer,
            "Not authorized"
        );
        require(
            escrow.status == EscrowStatus.FUNDED ||
                escrow.status == EscrowStatus.DISPUTED,
            "Cannot refund"
        );

        require(
            usdc.transfer(escrow.buyer, escrow.amount),
            "Refund failed"
        );

        escrow.status = EscrowStatus.REFUNDED;

        emit PaymentRefunded(_escrowId, escrow.buyer);
    }

    /**
     * @dev Dispute an escrow
     */
    function disputeEscrow(bytes32 _escrowId, string memory _reason)
        external
    {
        Escrow storage escrow = escrows[_escrowId];
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "Not authorized"
        );
        require(escrow.status == EscrowStatus.FUNDED, "Invalid status");

        escrow.status = EscrowStatus.DISPUTED;

        emit EscrowDisputed(_escrowId, _reason);
    }

    /**
     * @dev Get escrow details
     */
    function getEscrow(bytes32 _escrowId)
        external
        view
        returns (Escrow memory)
    {
        return escrows[_escrowId];
    }

    /**
     * @dev Check if delivery deadline passed
     */
    function isOverdue(bytes32 _escrowId) external view returns (bool) {
        return block.timestamp > escrows[_escrowId].deliveryDeadline;
    }

    /**
     * @dev Get all escrows count
     */
    function getEscrowsCount() external view returns (uint256) {
        return escrowIds.length;
    }

    /**
     * @dev Update platform fee (owner only)
     */
    function setPlatformFee(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 10, "Fee too high");
        platformFeePercent = _feePercent;
    }

    /**
     * @dev Update fee recipient (owner only)
     */
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid address");
        feeRecipient = _newRecipient;
    }
}
