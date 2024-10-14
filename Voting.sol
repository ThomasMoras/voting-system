// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );

    WorkflowStatus public workflowStatus;

    constructor() Ownable(msg.sender) {
        // Add admin to the whitelist
        whitelist[msg.sender] = Voter(true, false, 0);
    }

    mapping(address => Voter) whitelist;
    mapping(uint => Proposal) proposals;

    Proposal[] proposalsTab;
    Voter[] private voters;

    modifier onlyWhiteListed() {
        require(
            whitelist[msg.sender].isRegistered,
            "You are not part of whiteliste"
        );
        _;
    }

    function registerVoter(address _addr) external onlyOwner {
        require(
            workflowStatus == WorkflowStatus.RegisteringVoters,
            "Users can only be added during the voting registration phase"
        );
        Voter memory voter = Voter(true, false, 0);
        whitelist[_addr] = voter;
        emit VoterRegistered(_addr);
    }

    /*
     * Increase workflow step by 1
     */
    function goToNextStep() external onlyOwner {
        WorkflowStatus prev = workflowStatus;
        workflowStatus = WorkflowStatus(uint(workflowStatus) + 1);
        emit WorkflowStatusChange(prev, workflowStatus);
    }

    // Allow whitelist user to submit a proposal
    function submitProposal(
        uint _proposalId,
        string calldata _description
    ) external onlyWhiteListed {
        require(
            workflowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Propositions can only be added during the proposal registration phase"
        );
        require(bytes(_description).length > 0, "Description can not be empty");
        Proposal memory proposal = Proposal(_description, 0);
        proposals[_proposalId] = proposal;
        proposalsTab.push(proposal);
        emit ProposalRegistered(_proposalId);
    }

    // Allow whitelist user to submit a vote
    function submitVote(uint _proposalId) external onlyWhiteListed {
        require(
            workflowStatus == WorkflowStatus.VotingSessionStarted,
            "Votes can only be submitted during the voting session phase"
        );
        require(!whitelist[msg.sender].hasVoted, "You have already voted");

        // Une proposition à forcement une description non vide
        // Permet de vérifier si la proposition existe
        // Evite de parcourir le tableau (économise du gas)
        require(
            bytes(proposals[_proposalId].description).length > 0,
            "This proposal does not exist"
        );
        // Update voter
        Voter memory voter = Voter(true, true, _proposalId);
        whitelist[msg.sender] = voter;
        voters.push(voter);
        emit Voted(msg.sender, _proposalId);
    }

    function countVotes() external onlyOwner {
        require(
            workflowStatus == WorkflowStatus.VotingSessionEnded,
            "Votes can only be counted once the voting phase is completed"
        );
        for (uint i = 0; i < voters.length; i++) {
            proposals[voters[i].votedProposalId].voteCount += 1;
        }
    }

    // Retrieve the winning proposal
    function getWinner()
        external
        view
        onlyWhiteListed
        returns (Proposal memory)
    {
        Proposal memory winner;
        uint max = proposals[0].voteCount;
        for (uint i = 1; i < proposalsTab.length; i++) {
            if (max < proposals[i].voteCount) {
                max = proposals[i].voteCount;
                winner = proposalsTab[i];
            }
        }
        return winner;
    }

    // Get all voters
    function getVoters()
        external
        view
        onlyWhiteListed
        returns (Voter[] memory)
    {
        return voters;
    }

    // Return voter informations
    function getVoter(
        uint index
    ) public view onlyWhiteListed returns (bool, bool, uint) {
        return (
            voters[index].isRegistered,
            voters[index].hasVoted,
            voters[index].votedProposalId
        );
    }

    // Get number of voters
    function getVotersLength() external view onlyWhiteListed returns (uint) {
        return voters.length;
    }
}
