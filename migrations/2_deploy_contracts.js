const ERC20Enhanced = artifacts.require("ERC20Enhanced");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(ERC20Enhanced, "MyEnhancedToken", "MET", 10_000_000, {
        from: accounts[0],
    });
};
