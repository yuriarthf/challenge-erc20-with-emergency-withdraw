const ERC20Enhanced = artifacts.require("ERC20Enhanced");

module.exports = function(deployer) {
    deployer.deploy(ERC20Enhanced, "MyEnhancedToken", "MET", 10_000_000);
};
