pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Enhanced is ERC20 {

    /// @dev Domain hash
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

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
        require(!emergency[tokenHolder].isBlacklisted, string(abi.encodePacked(tokenHolder, " is blacklisted")));
        _;
    }

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Register an emergency address (backup address) for the msg.sender.
     *
     * Emits a {RegisterEmergencyAddress} event.
     *
     * Requirements:
     *
     * - msg.sender should not be blacklisted
     * - emergencyAddress should not be blacklisted
     */
    function registerEmergencyAddress(address emergencyAddress) external isNotBlacklisted(msg.sender) isNotBlacklisted(emergencyAddress) {
        emergency[msg.sender].emergencyAddress = emergencyAddress;

        emit RegisterEmergencyAddress(msg.sender, emergencyAddress);
    }

    /**
     * @dev Emergency withdraw using a signed message.
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
                keccak256(bytes("1")),
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
        bytes32 digest = keccak256(abi.encodePacked(uint16(0x1901), domainSeparator, hashStruct));

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