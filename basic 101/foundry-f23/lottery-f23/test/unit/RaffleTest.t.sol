// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    // events
    event EnteredRaffle(address indexed, player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function TestRaffleInitiliazesOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ///////////////////////////
    ///EnterRaffle//////////////
    ///////////////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // arrange
        vm.prank(PLAYER);

        // act/assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
        //assert
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer[0];
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventsOnentrance() public {
        vm.prank();
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.EnteredRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ////////////////////////////
    ///////CheckUpkeep//////////
    ////////////////////////////

    function checkUpKeepReturnsFalseIfItHas() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // act

        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        //assert
        assert(upkeepNeeded == false);

        //////////////////////////////////////
        /// perform upkeep needed ///////////
        ////////////////////////////////////
    }
    function testPerformUpkeepCanOnlyRunIfCheckupkeepIsTrue() public {
        // arrenge
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // act /    assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        // act/assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequesId()
        public
        raffleEnteredAndTimePassed
    {
        // act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit the req id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(rState) == 1);
    }

    ////////////////////////////////
    /////fullfill Random words /////
    ///////////////////////////////

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerFormUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed {
        // arrange
        vm.expectRevert("non existent request");

        vrfCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
    {
        // arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address (1)
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emit the req id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 previousTimeStamp = raffle.getLatestTimeStamp();
        // pretend to be chainlink vrf and get the random number and pick winner!

        vrfCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //Assert
        assert(uint256(raffle.raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLatestTimeStamp());
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);
    }
}
