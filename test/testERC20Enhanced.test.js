const ERC20Enhanced = artifacts.require("ERC20Enhanced");
const sigUtil = require("eth-sig-util");

contract("ERC20Enhanced", (accounts) => {
    let erc20Enhanced;
    let tokenName;
    let chainId;
    let verifyingContract;
    const initialSupply = 10_000_000;
    const decimals = 18;

    // Private key to sign Typed Data (from accounts[0])
    const privateKeyString =
        "0x7d455b74192b01dce514a5ddc219708f350357806f66c53edea1971e62b44651";
    const signerPrivateKey = Buffer.from(privateKeyString.substring(2), "hex");

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

        // Define the domain separator
        const domain = [
            { name: "name", type: "string" },
            { name: "chainId", type: "uint256" },
            { name: "verifyingContract", type: "address" },
        ];
        const domainData = {
            name: tokenName,
            chainId: chainId,
            verifyingContract: verifyingContract,
        };

        // Define expiration
        const currentBlockTimestamp = (await web3.eth.getBlock("latest"))
            .timestamp;
        const expiration = currentBlockTimestamp + 24 * 60 * 60;

        // Define the emergency typed structure
        const emergencyWithdraw = [{ name: "expiration", type: "uint256" }];
        const emergencyWithdrawData = {
            expiration: expiration,
        };

        // Build message data
        const data = {
            types: {
                EIP712Domain: domain,
                EmergencyWithdraw: emergencyWithdraw,
            },
            domain: domainData,
            primaryType: "EmergencyWithdraw",
            message: emergencyWithdrawData,
        };

        // Get signature
        // const signature = (await web3.eth.sign(data, accounts[0])).substring(2);
        const signature = sigUtil
            .signTypedData_v4(signerPrivateKey, { data })
            .substring(2);
        assert.equal(
            sigUtil.recoverTypedSignature_v4({ data, sig: "0x" + signature }),
            accounts[0].toLowerCase()
        );

        // Get r, s and v
        const r = "0x" + signature.substring(0, 64);
        const s = "0x" + signature.substring(64, 128);
        const v = parseInt(signature.substring(128, 130), 16);

        // Rebuild signature and compare
        const rebuiltSignature = sigUtil.concatSig(
            Buffer.from(v.toString(), "hex"),
            Buffer.from(r.substring(2), "hex"),
            Buffer.from(s.substring(2), "hex")
        );
        assert.equal(
            parseInt(rebuiltSignature, 16) - parseInt("0x" + signature, 16),
            0
        );

        // Log ECDSA values
        console.log(`R: ${r}`);
        console.log(`S: ${s}`);
        console.log(`V: ${v}`);

        // Call emergencyWithdrawWithSig
        await erc20Enhanced.emergencyWithdrawWithSig(expiration, v, r, s);

        // Assert token balances
        assert.equal(await erc20Enhanced.balanceOf(accounts[0]), 0);
        assert.equal(
            await erc20Enhanced.balanceOf(accounts[1]),
            initialSupply * 10 ** decimals
        );
    });
});
