// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

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

    Proposal[] public proposalsTab;
    Voter[] private voters;
    Proposal public winner;

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
        whitelist[_addr] = Voter(true, false, 0);
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
        Proposal memory isProposal = proposals[_proposalId];
        uint proposalLength = bytes(isProposal.description).length;
        require(proposalLength == 0, "This propositional id is already used");
        require(bytes(_description).length > 0, "Description can not be empty");
        require(_proposalId > 0, "Propositional id must be greater than 0");
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

    function countVotes() private onlyOwner returns (bool) {
        require(
            workflowStatus == WorkflowStatus.VotingSessionEnded,
            "Votes can only be counted once the voting phase is completed"
        );
        for (uint i = 0; i < voters.length; i++) {
            // proposalsTab start to 0 index but voter can not submit proposal 0
            // So we need the -1 to get the right proposal
            proposalsTab[voters[i].votedProposalId - 1].voteCount += 1;
        }
        return true;
    }

    // Retrieve the winning proposal
    function getWinner() external onlyOwner returns (Proposal memory) {
        require(countVotes() == true, "Error on countVotes");
        uint max;
        for (uint i = 0; i < proposalsTab.length; i++) {
            if (max < proposalsTab[i].voteCount) {
                max = proposalsTab[i].voteCount;
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

    // ********************************************************
    // ************** ADDITIONNALS FUNCTIONS ******************
    // ********************************************************

    // Return voter informations
    function getVoter(
        uint index
    ) external view onlyWhiteListed returns (bool, bool, uint) {
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

    // Reset the voting process
    // The current whitelist is not reset
    function resetVotingSession() external onlyOwner {
        workflowStatus = WorkflowStatus.RegisteringVoters;
        winner = Proposal("", 0);
        delete proposalsTab;
        // reset voters
        for (uint i = 0; i < voters.length; i++) {
            voters[i].hasVoted = false;
            voters[i].votedProposalId = 0;
        }
    }

    // Remove user from whitelist
    function removeUserFromWhiteList(address _addr) external onlyOwner {
        whitelist[_addr] = Voter(false, false, 0);
    }

    // Return bool value according if user is whitelisted or not
    function isWhiteListedUser(address _addr) external view returns (bool) {
        return whitelist[_addr].isRegistered;
    }

    function getCurrentWorkflow() external view returns (string memory) {
        if (workflowStatus == WorkflowStatus.RegisteringVoters) {
            return "RegisteringVoters";
        } else if (
            workflowStatus == WorkflowStatus.ProposalsRegistrationStarted
        ) {
            return "ProposalsRegistrationStarted";
        } else if (
            workflowStatus == WorkflowStatus.ProposalsRegistrationEnded
        ) {
            return "ProposalsRegistrationEnded";
        } else if (workflowStatus == WorkflowStatus.VotingSessionStarted) {
            return "VotingSessionStarted";
        } else if (workflowStatus == WorkflowStatus.VotingSessionEnded) {
            return "VotingSessionEnded";
        } else if (workflowStatus == WorkflowStatus.VotesTallied) {
            return "VotesTallied";
        } else {
            revert("Invalid status");
        }
    }
}
