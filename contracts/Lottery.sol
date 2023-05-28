//task we are going to do
//1. enter the lottery (by paying some amount)
//2. pick a random winner (verifiably random)
//3. winner to be selected every X minutes or some times->completely automated

// Chainlink oracle ->randomness ,Automated Execution(chainlink keeper)
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

 import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
 import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
 import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
 import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

//errors
error Lottery_NotEnoughEth();
error Lottery_transactionFailed();
error Lottery_NotOpen();
error Lottery_upkeepNotNeeded(uint256 currentBalance,uint256 numPlayers,uint LotteryState);

/**
 * @title A sample Lottery Contract
 * @author Aryan raj
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev This implements ChainLink VRF v2 and chainlink keepers
 */

contract Lottery is VRFConsumerBaseV2, AutomationCompatibleInterface{

    //type declarations

    enum LotteryState{
        OPEN,
        CALCULATING
    }

    //state variables
    uint256 private immutable entryFee; //entry  fee amount
    address payable[] private players; //make payable who wins the lottery
    VRFCoordinatorV2Interface private immutable vrfCoordinator;  //random generator interface class
    bytes32 private immutable gasLane;  //gas fee to get random numbers
    uint64 private immutable subscriptionId;  //create a subscription id chainlink to pay gas fee to oracle chainlink
    uint16 private constant requestConfirmations=3;
    uint32 private immutable callBackGasLimit;
    uint32 private immutable numWords=1;

    //lottery variables
    address private recentWinner;
    LotteryState private s_LotteryState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable interval;

    //Events
    event RequestedLotteryWinner(uint256 indexed requestId);
    event LotteryEnter(address indexed player);
    event winnerPicked(address indexed winner);


    constructor(address vrfCoordinatorV2,uint256 entryFees,bytes32 gaslane,uint64 subscriptionID,uint32 callbackgaslimit,uint256 s_interval) VRFConsumerBaseV2(vrfCoordinatorV2) 
    {
        entryFee=entryFees;
        vrfCoordinator=VRFCoordinatorV2Interface(vrfCoordinatorV2);
        gasLane=gaslane;
        subscriptionId=subscriptionID;
        callBackGasLimit=callbackgaslimit;  
        s_LotteryState=LotteryState.OPEN;
        s_lastTimeStamp=block.timestamp;
        interval=s_interval;

    }

    //get enter in lottery
    function enterInLottery() public payable{
        if(msg.value < entryFee){
            revert Lottery_NotEnoughEth();
        }
        if(s_LotteryState!=LotteryState.OPEN)
        {
            revert Lottery_NotOpen();
        }
        players.push(payable(msg.sender));

        //emit an event when we update a dynamic array or mapping
        emit LotteryEnter(msg.sender);

    }
    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(bytes memory /* checkData */) public view override returns (bool upkeepNeeded,bytes memory /*performData*/){
            bool isOpen=LotteryState.OPEN==s_LotteryState;
            bool timePassed=((block.timestamp-s_lastTimeStamp)>interval);
            bool hasPlayers=(players.length > 0);
            bool hasBalance=address(this).balance > 0;
            upkeepNeeded=(isOpen && timePassed && hasPlayers && hasBalance);
            return (upkeepNeeded,"0X0");
        }

    function performUpkeep(bytes calldata /* performData */) external override  
    {
        //to choose random numbers first we will get random num then we will use that to choose our random lottery winner
        //request the random number
        //after getting ,do something with it
        //2 transaction process
        (bool upkeepNeeded, )=checkUpkeep("");
        if(!upkeepNeeded)
        {
            revert Lottery_upkeepNotNeeded(address(this).balance,players.length,uint256(s_LotteryState) );
        }
        s_LotteryState= LotteryState.CALCULATING;
        uint256 requestId=vrfCoordinator.requestRandomWords(
            gasLane,  //gaslane
            subscriptionId,
            requestConfirmations,
            callBackGasLimit,
            numWords
        );
        emit RequestedLotteryWinner(requestId);
    }
   

    function fulfillRandomWords(uint256 /*requestId*/,uint256[] memory randomWords) internal override{
        //the randow uint256 we will get and it will so huge so we do modulo to reduce it
        uint256 indexOfWinner=randomWords[0]%players.length;
        address payable _recentWinner=players[indexOfWinner];
        recentWinner=_recentWinner;
        s_LotteryState=LotteryState.OPEN;
        players=new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, )=_recentWinner.call{value:address(this).balance}("");
        //require(success)
        if(!success)
        {
            revert Lottery_transactionFailed();
        }
        emit winnerPicked(_recentWinner);
    }

    //getEntryFee :to show entryFee
    function getEntryFee() public view returns(uint256){
        return entryFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return players[index];
    }

    function getRecentWinner() public view returns (address) {
        return recentWinner;
    }

    function getLotteryState() public view returns (LotteryState){
        return s_LotteryState;
    }

    function getNumWords() public pure returns (uint256){
        return numWords;
    }

    function getNumberOfPlayers() public view returns(uint256){
        return players.length;
    }

    function getLatestTimeStamp() public view returns (uint256){
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns(uint256){
        return requestConfirmations;
    }
    function getInterval() public view returns(uint256){
        return interval;
    }
}