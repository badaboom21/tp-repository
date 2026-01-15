// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

interface IVoteNFT {
    function balanceOf(address owner) external view returns (uint256);
    function mint(address to) external returns (uint256);
}


contract SimpleVotingSystem is Ownable, AccessControl {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        address payable wallet;
        uint256 received;
    }

    enum WorkflowStatus {
        REGISTER_CANDIDATES,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }

    WorkflowStatus public workflowStatus;
    uint256 public voteStartTime;
    IVoteNFT public voteNFT;
    uint public winnerId;
    bool public winnerSet;

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    constructor(address voteNftAddress) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FOUNDER_ROLE, msg.sender);
        _grantRole(WITHDRAWER_ROLE, msg.sender);
        
        workflowStatus = WorkflowStatus.REGISTER_CANDIDATES;

        voteNFT = IVoteNFT(voteNftAddress);
    }

    modifier inStatus(WorkflowStatus expected) {
        require(workflowStatus == expected, "Bad workflow status");
        _;
    }

    event WorkflowStatusChanged(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    function setWorkflowStatus(WorkflowStatus newStatus) external onlyRole(ADMIN_ROLE) {
        WorkflowStatus previous = workflowStatus;
        workflowStatus = newStatus;

        if (newStatus == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }

        emit WorkflowStatusChanged(previous, newStatus);
    }

    function addAdmin(address user) external onlyOwner {
        _grantRole(ADMIN_ROLE, user);
    }

    function removeAdmin(address user) external onlyOwner {
        _revokeRole(ADMIN_ROLE, user);
    }

    receive() external payable {}

    event Withdrawn(address indexed to, uint256 amount);

    function withdraw(address payable to, uint256 amount)
        external
        onlyRole(WITHDRAWER_ROLE)
        inStatus(WorkflowStatus.COMPLETED)
    {
        require(to != address(0), "Invalid recipient");
        require(amount <= address(this).balance, "Insufficient contract balance");

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Withdraw failed");

        emit Withdrawn(to, amount);
    }


    function addWithdrawer(address user) external onlyRole(ADMIN_ROLE) {
        _grantRole(WITHDRAWER_ROLE, user);
    }

    function removeWithdrawer(address user) external onlyRole(ADMIN_ROLE) {
        _revokeRole(WITHDRAWER_ROLE, user);
    }


    event WinnerDesignated(uint indexed winnerId, string name, uint votes);

    function designateWinner()
        external
        onlyRole(ADMIN_ROLE)
        inStatus(WorkflowStatus.COMPLETED)
    {
        require(candidateIds.length > 0, "No candidates");
        require(!winnerSet, "Winner already set");

        uint bestId = candidateIds[0];
        uint bestVotes = candidates[bestId].voteCount;

        for (uint i = 1; i < candidateIds.length; i++) {
            uint id = candidateIds[i];
            uint v = candidates[id].voteCount;
            if (v > bestVotes) {
                bestVotes = v;
                bestId = id;
            }
        }

        winnerId = bestId;
        winnerSet = true;

        Candidate memory w = candidates[bestId];
        emit WinnerDesignated(w.id, w.name, w.voteCount);
    }

    function getWinner() external view returns (Candidate memory) {
        require(winnerSet, "Winner not set");
        return candidates[winnerId];
    }


    event CandidateFunded(address indexed founder, uint indexed candidateId, uint256 amount);

    function fundCandidate(uint candidateId)
        external
        payable
        onlyRole(FOUNDER_ROLE)
        inStatus(WorkflowStatus.FOUND_CANDIDATES)
    {
        require(candidateId > 0 && candidateId <= candidateIds.length, "Invalid candidate ID");
        require(msg.value > 0, "No ETH sent");

        Candidate storage c = candidates[candidateId];
        require(c.wallet != address(0), "Candidate wallet not set");

        (bool ok, ) = c.wallet.call{value: msg.value}("");
        require(ok, "Transfer failed");

        c.received += msg.value;

        emit CandidateFunded(msg.sender, candidateId, msg.value);
    }

    function addFounder(address user) external onlyRole(ADMIN_ROLE) {
        _grantRole(FOUNDER_ROLE, user);
    }

    function removeFounder(address user) external onlyRole(ADMIN_ROLE) {
        _revokeRole(FOUNDER_ROLE, user);
    }

    function addCandidate(string memory _name, address payable _wallet) public onlyRole(ADMIN_ROLE) inStatus(WorkflowStatus.REGISTER_CANDIDATES) {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        require(_wallet != address(0), "Invalid wallet");
        uint candidateId = candidateIds.length + 1;
            candidates[candidateId] = Candidate({
            id: candidateId,
            name: _name,
            wallet: _wallet,
            voteCount: 0,
            received: 0
        });
        candidateIds.push(candidateId);
    }

    function vote(uint _candidateId) public inStatus(WorkflowStatus.VOTE){
        require(block.timestamp >= voteStartTime + 1 hours, "Vote not open yet (1h delay)");
        require(candidateIds.length > 0, "No candidates registered");
        // require(!voters[msg.sender], "You have already voted");
        require(voteNFT.balanceOf(msg.sender) == 0, "Already has Vote NFT");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;
        voteNFT.mint(msg.sender);
    }

    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId].voteCount;
    }

    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

    function getCandidate(uint _candidateId) public view returns (Candidate memory) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId];
    }
}
