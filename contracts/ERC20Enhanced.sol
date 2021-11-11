pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Enhanced is ERC20 {

    /// @dev Domain hash
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @dev Emergency withdraw typehash
    bytes32 public constant EMERGENCY_WITHDRAW_TYPEHASH = keccak256("EmergencyWithdraw(uint256 expiration)");

    /// @dev EmergencyTransfer struct containing emergency address and blacklist flag
    struct EmergencyTransfer {
        address emergencyAddress;
        bool isBlacklisted;
    }

    /// @dev Mapping between addresses and it's emergency ones
    mapping (address => EmergencyTransfer) public emergency;

    /// @dev Emitted when a new emergency address has been defined
    event RegisterEmergencyAddress(address indexed tokenHolder, address indexed emergencyAddress);

    /// @dev Emmited when the emergency withdraw is used
    event EmergencyWithdraw(address indexed caller, address indexed signer, address indexed emergencyAddress, uint256 amount);

    /// @dev Check if address is not blacklisted
    modifier isNotBlacklisted(address tokenHolder) {
        require(!emergency[tokenHolder].isBlacklisted, "Address is blacklisted");
        _;
    }

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply * 10**decimals());
    }

    /**
     * @dev Register an emergency address (backup address) for the msg.sender.
     *
     * @param emergencyAddress The emergency address to be set
     *
     * Emits a {RegisterEmergencyAddress} event.
     *
     * Requirements:
     *
     * - msg.sender should not be blacklisted
     * - emergencyAddress should not be blacklisted
     */
    function registerEmergencyAddress(address emergencyAddress) external isNotBlacklisted(msg.sender) isNotBlacklisted(emergencyAddress) {
        require(emergencyAddress != msg.sender, "Provide a different emergency address");
        emergency[msg.sender].emergencyAddress = emergencyAddress;

        emit RegisterEmergencyAddress(msg.sender, emergencyAddress);
    }

    /**
     * @dev Get the emergency address of `tokenHolder`.
     *
     * @param tokenHolder Token Holder address
     *
     * Requirements:
     *
     * - tokenHolder must be different from the null address
     */
    function getEmergencyAddress(address tokenHolder) external view returns (address) {
        require(tokenHolder != address(0), "Please provide a valid address");
        return emergency[msg.sender].emergencyAddress;
    }

    /**
     * @dev Emergency withdraw using a signed message.
     *
     * @param _exp The EIP-712 signature expiration timestamp
     * @param v the recovery byte of the signature
     * @param r The first half of the ECDSA signature
     * @param s The second half of th ECDSA signature
     *
     * Emits a {EmergencyWithdraw} event.
     *
     * Requirements:
     *
     * - Message signer should not be the null address
     * - Block timestamp should less than _exp (Expiration timestamp)
     * - The emergency address should not be the null address
     * - The signer should not be blacklisted
     * - Balance of signer should be greater than ZERO
     */
    function emergencyWithdrawWithSig(uint256 _exp, uint8 v, bytes32 r, bytes32 s) public {

        // EIP-712 Domain Separator
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH, 
                keccak256(bytes(name())), 
                block.chainid,
                address(this)
            )
        );

        // EIP-712 hashStruct of EmergencyWithdraw
        bytes32 hashStruct = keccak256(
            abi.encode(
                EMERGENCY_WITHDRAW_TYPEHASH,
                _exp
            )
        );

        // EIP-191-compliant 712 hash
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, hashStruct));

        // Retrieve signer
        address signer = ecrecover(digest, v, r, s);

        // Check message integrity
        require(signer != address(0), "ECDSA: invalid signature");
        require(block.timestamp < _exp, "signature expired");

        // Check if the emergency address has been set and if it's not blacklisted
        require(emergency[signer].emergencyAddress != address(0), "Invalid emergency address");
        require(!emergency[signer].isBlacklisted, "Signer address is blacklisted");

        // Check if signer has any token
        require(balanceOf(signer) > 0, "No tokens available");

        uint256 signerTotalBalance = balanceOf(signer);
        transferFrom(signer, emergency[signer].emergencyAddress, signerTotalBalance);

        // Blacklist signer
        emergency[signer].isBlacklisted = true;

        emit EmergencyWithdraw(msg.sender, signer, emergency[signer].emergencyAddress, signerTotalBalance);
    }

    /**
     * @dev Transfer from `sender` to `recipient` an `amount` of tokens.
     *
     * @param sender The token sender address
     * @param recipient The token recipient address, will be set to emergency address if it's blacklisted
     * @param amount The amount of tokens to send
     * 
     * OBS: If the recipient is blacklisted, transfer amount to it's emergency address.
     *
     * Requirements:
     *
     * - `sender` should not be blacklisted
     * - Allowance should be greater than `amount`
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override isNotBlacklisted(sender) returns (bool) {
        // If recipient is blacklisted send tokens to it's emergency address
        if (emergency[recipient].isBlacklisted) recipient = emergency[recipient].emergencyAddress;
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Transfer to `recipient` an `amount` of tokens.
     *
     * @param recipient The token recipient address, will be set to emergency address if it's blacklisted
     * @param amount The amount of tokens to send
     * 
     * OBS: If the recipient is blacklisted, transfer amount to it's emergency address.
     *
     * Requirements:
     *
     * - msg.sender should not be blacklisted
     */
    function transfer(address recipient, uint256 amount) public override isNotBlacklisted(msg.sender) returns (bool) {
        // If recipient is blacklisted send tokens to it's emergency address
        if (emergency[recipient].isBlacklisted) recipient = emergency[recipient].emergencyAddress;
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

}