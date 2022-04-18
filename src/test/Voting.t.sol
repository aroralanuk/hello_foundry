// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";
import "../contracts/Voting.sol";

interface CheatCodes {
    function expectEmit(
        bool,
        bool,
        bool,
        bool
    ) external;
}

contract VotingTest is DSTest {
    using stdStorage for StdStorage;

    Vm private vm = Vm(HEVM_ADDRESS);
    CheatCodes constant cheats = CheatCodes(HEVM_ADDRESS);

    Ballot private testBallot;
    StdStorage private stdstore;
    address deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    bytes32[] proposals;
    address[] initVoters;
    address[] newVoters;

    event EveryoneHasVoted(uint _totalVotes, bytes32 _winningProposal);

    function setUp() public {
        
        proposals.push("buy constitution");
        proposals.push("sue the SEC");
        proposals.push("raise a 1bil fund");
        // Deploy ballot contract
        testBallot = new Ballot(proposals);
        
        initVoters.push(address(1));
        initVoters.push(address(2));
        initVoters.push(address(3));
        testBallot.giveRightToVote(initVoters);
    }

    function testInitialVoterWeight() public {
        // emit log("Strring: " + testBallot.getVoterWeights(address(1)));
        assertEq(testBallot.getVoterWeights(address(1)), 1e18);
        assertEq(testBallot.getVoterWeights(address(2)), 1e18);
        assertEq(testBallot.getVoterWeights(address(3)), 1e18);
    }

    function testFailUnauthAlloc() public {
        delete newVoters;
        newVoters.push(address(4));

        vm.startPrank(address(1));
        testBallot.giveRightToVote(newVoters);
        vm.stopPrank();
    }

    function testFailVoterAlreadyExists() public {
        delete newVoters;
        newVoters.push(address(1));
        testBallot.giveRightToVote(newVoters);
    }

    function testDelegateVotes() public {
        vm.startPrank(address(1));
        testBallot.delegate(address(2));
        vm.stopPrank();

        vm.startPrank(address(3));
        testBallot.delegate(address(deployer));
        vm.stopPrank();

        assertEq(testBallot.getVoterWeights(address(2)), 2e18);
        assertEq(testBallot.getVoterWeights(address(deployer)), 2e18);
    }

    function testFailDelegateToSelf() public {
        testBallot.delegate(address(deployer));
    }

    function testFailDelegateToZeroAddress() public {
        testBallot.delegate(address(0));
    }

    function testFailDelegateLoop() public {
        vm.startPrank(address(1));
        testBallot.delegate(address(2));
        vm.stopPrank();

        vm.startPrank(address(2));
        testBallot.delegate(address(3));
        vm.stopPrank();

        vm.startPrank(address(3));
        testBallot.delegate(address(1));
        vm.stopPrank();
    }

    function testVote() public {

        testBallot.vote(0);

        vm.startPrank(address(1));
        testBallot.vote(1);
        vm.stopPrank();

        vm.startPrank(address(2));
        testBallot.vote(2);
        vm.stopPrank();

        vm.startPrank(address(3));
        testBallot.vote(0);
        vm.stopPrank();

        assertEq(testBallot.winningProposal(),0);
    }

    function testFailVoteTie() public {

        testBallot.vote(0);

        vm.startPrank(address(1));
        testBallot.vote(1);
        vm.stopPrank();

        vm.startPrank(address(2));
        testBallot.vote(1);
        vm.stopPrank();

        vm.startPrank(address(3));
        testBallot.vote(0);
        vm.stopPrank();

        assertEq(testBallot.winningProposal(),1);
    }

    function testFailVoteAfterDelegate() public {
        vm.startPrank(address(1));
        testBallot.delegate(address(2));
        testBallot.vote(0);
        vm.stopPrank();
    }

    function testFailDelegateAfterVote() public {
        vm.startPrank(address(1));
        testBallot.vote(0);
        testBallot.delegate(address(2));
        vm.stopPrank();
    }

    function testVoteAfterDelegate() public {
        vm.startPrank(address(1));
        testBallot.delegate(address(2));
        vm.stopPrank();

        vm.startPrank(address(2));
        testBallot.vote(1);
        vm.stopPrank();

        vm.startPrank(address(3));
        testBallot.delegate(deployer);
        vm.stopPrank();

        testBallot.vote(1);
        assertEq(testBallot.winningProposal(),1);
    }

    function testDelegateAfterVote() public {
        vm.startPrank(address(3));
        testBallot.delegate(deployer);
        vm.stopPrank();

        testBallot.vote(1);

        vm.startPrank(address(1));
        testBallot.delegate(address(2));
        vm.stopPrank();

        vm.startPrank(address(2));
        testBallot.vote(1);
        vm.stopPrank();

        assertEq(testBallot.winningProposal(),1);
    }

    function testAddVoter() public {
        testBallot.addVoter(address(4));
        assertEq(testBallot.getVoterWeights(address(4)), 1e18);
    }

    function testFailUnauthAddVoter() public {
        vm.startPrank(address(3));
        testBallot.addVoter(address(4));
        vm.stopPrank();
    }

    function testQuadraticVote() public {
        testBallot.addVoter(address(4));

        // 1->3 and 2->3 vs chair and 4
        vm.startPrank(address(1));
        testBallot.delegate(address(3));
        vm.stopPrank();
        vm.startPrank(address(2));
        testBallot.delegate(address(3));
        vm.stopPrank();

        vm.startPrank(address(3));
        testBallot.vote(0);
        vm.stopPrank();

        vm.startPrank(deployer);
        testBallot.vote(1);
        vm.stopPrank();

        vm.startPrank(address(4));
        testBallot.vote(1);
        vm.stopPrank();

        assertEq(testBallot.winningProposal(),1);
        assertTrue(testBallot.checkIfEveryoneVoted());
    }

    function testExpectEmit() public {




        testBallot.addVoter(address(4));

        // // 1->3 and 2->3 vs chair and 4
        vm.startPrank(address(1));
        testBallot.delegate(address(3));
        vm.stopPrank();
        vm.startPrank(address(2));
        testBallot.delegate(address(3));
        vm.stopPrank();

        vm.startPrank(address(3));
        testBallot.vote(0);
        vm.stopPrank();

        vm.startPrank(deployer);
        testBallot.vote(1);
        vm.stopPrank();

        cheats.expectEmit(true, true, false, false);
        emit EveryoneHasVoted(5, bytes32("sue the SEC"));

        vm.startPrank(address(4));
        testBallot.vote(1);
        vm.stopPrank();
    }

}