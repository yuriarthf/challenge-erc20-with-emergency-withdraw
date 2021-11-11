pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract ERC20Enhanced is EIP712, ERC20 {

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

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) EIP712(name_, "1") ERC20(name_, symbol_) {
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
     * @param signature The ECDSA signature
     * @param deadline The EIP-712 signature expiration/deadline timestamp 
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
    function emergencyWithdrawWithSig(bytes calldata signature, uint256 deadline) public {

        // EIP-712 digest
        bytes32 digest = _hashTypedDataV4(keccak256(
            abi.encode(
                EMERGENCY_WITHDRAW_TYPEHASH,
                deadline
            )
        ));

        // Retrieve signer
        address signer = ECDSA.recover(digest, signature);

        // Check message integrity
        require(signer != address(0), "ECDSA: invalid signature");
        require(block.timestamp < deadline, "signature expired");

        // Check if the emergency address has been set and if it's not blacklisted
        require(
            emergency[signer].emergencyAddress != address(0), 
            string(
                abi.encodePacked("Invalid emergency address for: ", _addressToString(signer))
            )
        );
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

    /**
     * @dev Convert address to string.
     *
     * @param _addr Address to be converted to string
     *
     */
    function _addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(51);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }
}