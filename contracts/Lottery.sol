//task we are going to do
//1. enter the lottery (by paying some amount)
//2. pick a random winner (verifiably random)
//3. winner to be selected every X minutes or some times->completely automated

// Chainlink oracle ->randomness ,Automated Execution(chainlink keeper)
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


error Lottery_NotEnoughEth();
error Lottery_transactionFailed();
contract Lottery is VRFConsumerBaseV2{

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

    //Events
    event LotteryEnter(address indexed player);
    event RequestedLotteryWinner(uint256 indexed requestId);
    event winnerPicked(address indexed winner);


    constructor(address vrfCoordinatorV2,uint256 entryFees,bytes32 gaslane,uint64 subscriptionID,uint32 callbackgaslimit) VRFConsumerBaseV2(vrfCoordinatorV2) 
    {
        entryFee=entryFees;
        vrfCoordinator=VRFCoordinatorV2Interface(vrfCoordinatorV2);
        gasLane=gaslane;
        subscriptionId=subscriptionID;
        callBackGasLimit=callbackgaslimit;  
    }

    //get enter in lottery
    function enterInLottery() public payable{
        if(msg.value < entryFee){
            revert Lottery_NotEnoughEth();
        }
        players.push(payable(msg.sender));

        //emit an event when we update a dynamic array or mapping
        emit LotteryEnter(msg.sender);

    }

    //getEntryFee :to show entryFee
    function getEntryFee() public view returns(uint256){
        return entryFee;
    }

    function pickRandomWinner() external{
        //to choose random numbers first we will get random num then we will use that to choose our random lottery winner
        //request the random number
        //after getting ,do something with it
        //2 transaction process
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
        (bool success, )=_recentWinner.call{value:address(this).balance}("");
        //require(success)
        if(!success)
        {
            revert Lottery_transactionFailed();
        }
        emit winnerPicked(_recentWinner);
    }

    function getPlayer(uint256 index) public view returns (address) {
        return players[index];
    }

    function getRecentWinner() public view returns (address) {
        return recentWinner;
    }
}