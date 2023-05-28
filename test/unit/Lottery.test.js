const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { getNamedAccounts, deployments, ethers } = require("hardhat")
const { assert } = require("chai")

!developmentChains.includes(network.name) ? describe.skip : describe("Lottery unit Tests", async function () {
    let lottery, vrfCoordinatorV2Mock;
    const chainId = network.config.chainId;

    beforeEach(async function () {
        const { deployer } = await getNamedAccounts();
        await deployments.fixture(["all"]);
        lottery = await ethers.getContract("Lottery", deployer);
        vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock", deployer);
    });

    describe("constructor", async function () {
        it("initializes the lottery correctly", async function () {
            const lotteryState = await lottery.getLotteryState();
            const interval = await lottery.getInterval();
            assert.equal(lotteryState.toString(), "0");
            assert.equal(interval.toString(), networkConfig[chainId].interval); // Updated assertion
        });
    });
});
