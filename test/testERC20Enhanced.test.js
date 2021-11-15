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
    let tokenName;
    let chainId;
    let verifyingContract;
    const initialSupply = 10_000_000;
    const decimals = 18;

    // Private key to sign Typed Data (from accounts[0])
    const privateKeyString =
        "0xe736a0bff423bcda1fbd31e55ba436bbcc81d3ecf84ec9f652265c2979cc3828";

    before(async () => {
        erc20Enhanced = await ERC20Enhanced.deployed();
        tokenName = await erc20Enhanced.name.call();
        chainId = parseInt(await web3.eth.getChainId(), 10);
        verifyingContract = erc20Enhanced.address;

        // Log contract information
        console.log(`Token Name: ${tokenName}`);
        console.log(`Chain ID: ${chainId}`);
        console.log(`Contract address: ${verifyingContract}`);
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

    it("Test emergency withdraw using signed message...", async () => {
        // Double check emergency address
        assert.equal(
            await erc20Enhanced.getEmergencyAddress(accounts[0]),
            accounts[1]
        );

        // EIP712Domain Typed Data
        const EIP712Domain =
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";

        // Get Domain Separator
        const DOMAIN_SEPARATOR = keccak256(
            defaultAbiCoder.encode(
                ["bytes32", "bytes32", "bytes32", "uint256", "address"],
                [
                    keccak256(toUtf8Bytes(EIP712Domain)),
                    keccak256(toUtf8Bytes(tokenName)),
                    keccak256(toUtf8Bytes("1")),
                    chainId,
                    verifyingContract,
                ]
            )
        );

        // Get Emergency Withdraw Type Hash and Hash Struc
        const EMERGENCY_WITHDRAW_TYPEHASH = keccak256(
            toUtf8Bytes("EmergencyWithdraw(uint256 expiration)")
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
