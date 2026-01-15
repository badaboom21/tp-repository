// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {SimpleVotingSystem} from "../src/SimplevotingSystem.sol";
import {VoteNFT} from "../src/VoteNFT.sol";

contract SimpleVotingSystemTest is Test {
    SimpleVotingSystem voting;
    VoteNFT voteNft;

    address admin;
    address founder;
    address withdrawer;

    address voter1;
    address voter2;

    address payable candidateWallet1;
    address payable candidateWallet2;

    function setUp() public {
        admin = makeAddr("admin");
        founder = makeAddr("founder");
        withdrawer = makeAddr("withdrawer");

        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");

        candidateWallet1 = payable(makeAddr("candidateWallet1"));
        candidateWallet2 = payable(makeAddr("candidateWallet2"));

        // On donne des ETH aux comptes qui vont envoyer des tx
        vm.deal(admin, 10 ether);
        vm.deal(founder, 10 ether);
        vm.deal(withdrawer, 10 ether);
        vm.deal(voter1, 10 ether);
        vm.deal(voter2, 10 ether);

        // Déploiement des contrats
        vm.startPrank(admin);
        voteNft = new VoteNFT(admin);
        voting = new SimpleVotingSystem(address(voteNft));

        voteNft.grantRole(voteNft.MINTER_ROLE(), address(voting));

        voting.addFounder(founder);
        voting.addWithdrawer(withdrawer);

        vm.stopPrank();
    }

    function _setStatus(uint8 status) internal {
        vm.prank(admin);
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus(status));
    }

    function _addCandidate(string memory name, address payable wallet) internal {
        vm.prank(admin);
        voting.addCandidate(name, wallet);
    }

    function _openVoteAndWait1h() internal {
        _setStatus(2); 
        vm.warp(block.timestamp + 1 hours);
    }

    function test_AddCandidate() public {
        // Non-admin => revert
        vm.prank(voter1);
        vm.expectRevert(); 
        voting.addCandidate("Alice", candidateWallet1);

        // Admin OK en phase REGISTER_CANDIDATES
        _addCandidate("Alice", candidateWallet1);
        assertEq(voting.getCandidatesCount(), 1);

        _setStatus(1); 
        vm.prank(admin);
        vm.expectRevert(bytes("Bad workflow status"));
        voting.addCandidate("Bob", candidateWallet2);
    }

    function test_FundCandidate() public {
        _addCandidate("Alice", candidateWallet1);

        // Pas en FOUND_CANDIDATES => revert
        vm.prank(founder);
        vm.expectRevert(bytes("Bad workflow status"));
        voting.fundCandidate{value: 1 ether}(1);

        _setStatus(1);

        // Non-founder => revert
        vm.prank(voter1);
        vm.expectRevert();
        voting.fundCandidate{value: 1 ether}(1);

        // Founder => OK et l'argent arrive au wallet du candidat
        uint256 beforeBal = candidateWallet1.balance;
        vm.prank(founder);
        voting.fundCandidate{value: 1 ether}(1);
        assertEq(candidateWallet1.balance, beforeBal + 1 ether);
        SimpleVotingSystem.Candidate memory c = voting.getCandidate(1);
        assertEq(c.received, 1 ether);
    }

    function test_Vote_Reverts() public {
        _addCandidate("Alice", candidateWallet1);

        _setStatus(2); 
        // Pas encore 1h -> revert
        vm.prank(voter1);
        vm.expectRevert(bytes("Vote not open yet (1h delay)"));
        voting.vote(1);
    }

    function test_Vote_MintsNFT() public {
        _addCandidate("Alice", candidateWallet1);

        _openVoteAndWait1h();

        // voter1 vote => OK
        vm.prank(voter1);
        voting.vote(1);

        assertEq(voteNft.balanceOf(voter1), 1);

        // Second vote => revert car NFT déjà possédé
        vm.prank(voter1);
        vm.expectRevert(bytes("Already has Vote NFT"));
        voting.vote(1);
    }

    function test_Vote_OnlyInVotePhase() public {
        _addCandidate("Alice", candidateWallet1);

        // Pas en VOTE => revert
        vm.prank(voter1);
        vm.expectRevert(bytes("Bad workflow status"));
        voting.vote(1);
    }

    function test_DesignateWinner() public {
        _addCandidate("Alice", candidateWallet1);
        _addCandidate("Bob", candidateWallet2);

        // Ouvrir le vote + attendre 1h
        _openVoteAndWait1h();

        // voter1 vote Alice (id=1)
        vm.prank(voter1);
        voting.vote(1);

        // voter2 vote Bob (id=2)
        vm.prank(voter2);
        voting.vote(2);

        // Pas en COMPLETED => revert
        vm.prank(admin);
        vm.expectRevert(bytes("Bad workflow status"));
        voting.designateWinner();

        // Passe en COMPLETED
        _setStatus(3);

        // Non-admin => revert
        vm.prank(voter1);
        vm.expectRevert();
        voting.designateWinner();

        // Admin => OK
        vm.prank(admin);
        voting.designateWinner();

        SimpleVotingSystem.Candidate memory w = voting.getWinner();
        assertEq(w.id, 1);
        assertEq(w.voteCount, 1);
    }


    function test_Withdraw() public {
        // Envoie de l'ETH au contrat via receive()
        vm.prank(admin);
        (bool ok, ) = address(voting).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(voting).balance, 1 ether);

        // Pas en COMPLETED 
        vm.prank(withdrawer);
        vm.expectRevert(bytes("Bad workflow status"));
        voting.withdraw(payable(withdrawer), 0.5 ether);

        _setStatus(3);

        vm.prank(voter1);
        vm.expectRevert();
        voting.withdraw(payable(voter1), 0.5 ether);

        uint256 before = withdrawer.balance;
        vm.prank(withdrawer);
        voting.withdraw(payable(withdrawer), 0.5 ether);

        assertEq(withdrawer.balance, before + 0.5 ether);
        assertEq(address(voting).balance, 0.5 ether);
    }
}
