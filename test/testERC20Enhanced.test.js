const ERC20Enhanced = artifacts.require("ERC20Enhanced");
const ethers = require("ethers");
const {
    keccak256,
    defaultAbiCoder,
    toUtf8Bytes,
    solidityPack,
} = require("ethers").utils;
const ethUtil = require("ethereumjs-util");

contract("ERC20Enhanced", (accounts) => {
    let erc20Enhanced;
    let name;
    const initialSupply = 10_000_000;
    const decimals = 18;

    // EIP712 related
    let DOMAIN_SEPARATOR_TYPEHASH;
    let DOMAIN_SEPARATOR;
    let EMERGENCY_WITHDRAW_TYPEHASH;

    // Private key to sign Typed Data (from accounts[0])
    const privateKeyString =
        "0x8cbf87e3b1b67c315c7b475cfc4a9ee9552e536fa6157556c4f4c4dbb8c2feee";

    before(async () => {
        erc20Enhanced = await ERC20Enhanced.deployed();
        name = await erc20Enhanced.name();
    });

    it("Register emergency address...", async () => {
        // Register accounts[1] as the emergency address
        await erc20Enhanced.registerEmergencyAddress(accounts[1]);

        // Assert that the emergency address has been added
        assert.equal(
            (await erc20Enhanced.emergency(accounts[0])).emergencyAddress,
            accounts[1]
        );
    });

    it("Validate hashes...", async () => {
        // EIP712Domain Typed Data
        DOMAIN_SEPARATOR_TYPEHASH = keccak256(
            toUtf8Bytes(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            )
        );

        // Domain Separator validation
        assert.equal(name, "MyEnhancedToken");
        DOMAIN_SEPARATOR = keccak256(
            defaultAbiCoder.encode(
                ["bytes32", "bytes32", "bytes32", "uint256", "address"],
                [
                    DOMAIN_SEPARATOR_TYPEHASH,
                    keccak256(toUtf8Bytes(name)),
                    keccak256(toUtf8Bytes("1")),
                    1,
                    erc20Enhanced.address,
                ]
            )
        );
        assert.equal(
            await erc20Enhanced.getDomainSeparatorHash(),
            DOMAIN_SEPARATOR
        );

        // EmergencyWithdraw type hash
        EMERGENCY_WITHDRAW_TYPEHASH = keccak256(
            toUtf8Bytes("EmergencyWithdraw(address from,uint256 expiration)")
        );
        assert.equal(
            await erc20Enhanced.EMERGENCY_WITHDRAW_TYPEHASH(),
            EMERGENCY_WITHDRAW_TYPEHASH
        );
    });
    it("Test emergency withdraw using signed message...", async () => {
        // Double check emergency address
        assert.equal(
            await erc20Enhanced.getEmergencyAddress(accounts[0]),
            accounts[1]
        );

        // Define expiration as the Maximum uint256 value
        const EXPIRATION = ethers.constants.MaxUint256;
        const EMERGENCY_WITHDRAW_HASHSTRUCT = keccak256(
            defaultAbiCoder.encode(
                ["bytes32", "address", "uint256"],
                [EMERGENCY_WITHDRAW_TYPEHASH, accounts[0], EXPIRATION]
            )
        );

        // Get digest
        const digest = keccak256(
            solidityPack(
                ["bytes1", "bytes1", "bytes32", "bytes32"],
                [
                    "0x19",
                    "0x01",
                    DOMAIN_SEPARATOR,
                    EMERGENCY_WITHDRAW_HASHSTRUCT,
                ]
            )
        );

        // Get ECDSA signature
        const sig = ethUtil.ecsign(
            ethUtil.toBuffer(digest),
            ethUtil.toBuffer(privateKeyString)
        );

        const publicKey = ethUtil.ecrecover(
            ethUtil.toBuffer(digest),
            sig.v,
            sig.r,
            sig.s
        );
        const address = ethUtil.addHexPrefix(
            ethUtil.pubToAddress(publicKey).toString("hex")
        );

        // Assert address is equal to accounts[0]
        console.log(`Recovered address: ${address}`);
        assert.equal(address, accounts[0].toLowerCase());

        // Call emergencyWithdrawWithSig
        await erc20Enhanced.emergencyWithdrawWithSig(
            accounts[0],
            EXPIRATION,
            ethUtil.bufferToInt(sig.v),
            ethUtil.addHexPrefix(sig.r.toString("hex")),
            ethUtil.addHexPrefix(sig.s.toString("hex"))
        );

        // Assert token balances
        assert.equal(await erc20Enhanced.balanceOf(accounts[0]), 0);
        assert.equal(
            await erc20Enhanced.balanceOf(accounts[1]),
            initialSupply * 10 ** decimals
        );
    });
});
