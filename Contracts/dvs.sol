
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    // Structs
    struct Candidate {
        uint256 id;
        string name;
        string description;
        uint256 voteCount;
        bool exists;
    }
    
    struct Election {
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 totalVotes;
        uint256[] candidateIds;
    }
    
    // State variables
    address public admin;
    uint256 public electionCount;
    uint256 public candidateCount;
    
    mapping(uint256 => Election) public elections;
    mapping(uint256 => Candidate) public candidates;
    mapping(uint256 => mapping(address => bool)) public hasVoted; // electionId => voter => bool
    mapping(address => bool) public registeredVoters;
    
    // Events
    event ElectionCreated(uint256 indexed electionId, string title, uint256 startTime, uint256 endTime);
    event CandidateAdded(uint256 indexed electionId, uint256 indexed candidateId, string name);
    event VoteCast(uint256 indexed electionId, uint256 indexed candidateId, address indexed voter);
    event VoterRegistered(address indexed voter);
    event ElectionEnded(uint256 indexed electionId, uint256 totalVotes);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(registeredVoters[msg.sender], "You must be a registered voter");
        _;
    }
    
    modifier electionExists(uint256 _electionId) {
        require(_electionId < electionCount, "Election does not exist");
        _;
    }
    
    modifier electionActive(uint256 _electionId) {
        Election storage election = elections[_electionId];
        require(election.isActive, "Election is not active");
        require(block.timestamp >= election.startTime, "Election has not started yet");
        require(block.timestamp <= election.endTime, "Election has ended");
        _;
    }
    
    modifier hasNotVoted(uint256 _electionId) {
        require(!hasVoted[_electionId][msg.sender], "You have already voted in this election");
        _;
    }
    
    // Constructor
    constructor() {
        admin = msg.sender;
        electionCount = 0;
        candidateCount = 0;
    }
    
    // Core Function 1: Create Election
    function createElection(
        string memory _title,
        string memory _description,
        uint256 _durationInMinutes,
        string[] memory _candidateNames,
        string[] memory _candidateDescriptions
    ) public onlyAdmin returns (uint256) {
        require(bytes(_title).length > 0, "Election title cannot be empty");
        require(_candidateNames.length > 0, "At least one candidate required");
        require(_candidateNames.length == _candidateDescriptions.length, "Candidate names and descriptions must match");
        require(_durationInMinutes > 0, "Duration must be greater than 0");
        
        uint256 electionId = electionCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_durationInMinutes * 1 minutes);
        
        Election storage newElection = elections[electionId];
        newElection.title = _title;
        newElection.description = _description;
        newElection.startTime = startTime;
        newElection.endTime = endTime;
        newElection.isActive = true;
        newElection.totalVotes = 0;
        
        // Add candidates to this election
        for (uint256 i = 0; i < _candidateNames.length; i++) {
            uint256 candidateId = candidateCount;
            
            candidates[candidateId] = Candidate({
                id: candidateId,
                name: _candidateNames[i],
                description: _candidateDescriptions[i],
                voteCount: 0,
                exists: true
            });
            
            newElection.candidateIds.push(candidateId);
            candidateCount++;
            
            emit CandidateAdded(electionId, candidateId, _candidateNames[i]);
        }
        
        electionCount++;
        
        emit ElectionCreated(electionId, _title, startTime, endTime);
        return electionId;
    }
    
    // Core Function 2: Register Voter
    function registerVoter(address _voter) public onlyAdmin {
        require(_voter != address(0), "Invalid voter address");
        require(!registeredVoters[_voter], "Voter already registered");
        
        registeredVoters[_voter] = true;
        emit VoterRegistered(_voter);
    }
    
    // Allow voters to self-register (in a real system, this might require additional verification)
    function selfRegister() public {
        require(!registeredVoters[msg.sender], "Already registered");
        registeredVoters[msg.sender] = true;
        emit VoterRegistered(msg.sender);
    }
    
    // Core Function 3: Cast Vote
    function castVote(uint256 _electionId, uint256 _candidateId) 
        public 
        onlyRegisteredVoter 
        electionExists(_electionId) 
        electionActive(_electionId) 
        hasNotVoted(_electionId) 
    {
        require(candidates[_candidateId].exists, "Candidate does not exist");
        
        // Verify candidate belongs to this election
        bool candidateInElection = false;
        Election storage election = elections[_electionId];
        
        for (uint256 i = 0; i < election.candidateIds.length; i++) {
            if (election.candidateIds[i] == _candidateId) {
                candidateInElection = true;
                break;
            }
        }
        
        require(candidateInElection, "Candidate not part of this election");
        
        // Record the vote
        hasVoted[_electionId][msg.sender] = true;
        candidates[_candidateId].voteCount++;
        election.totalVotes++;
        
        emit VoteCast(_electionId, _candidateId, msg.sender);
    }
    
    // Utility Functions
    function endElection(uint256 _electionId) public onlyAdmin electionExists(_electionId) {
        Election storage election = elections[_electionId];
        require(election.isActive, "Election is not active");
        
        election.isActive = false;
        emit ElectionEnded(_electionId, election.totalVotes);
    }
    
    function getElectionResults(uint256 _electionId) 
        public 
        view 
        electionExists(_electionId) 
        returns (
            string memory title,
            uint256 totalVotes,
            uint256[] memory candidateIds,
            string[] memory candidateNames,
            uint256[] memory voteCounts
        ) 
    {
        Election storage election = elections[_electionId];
        uint256 numCandidates = election.candidateIds.length;
        
        string[] memory names = new string[](numCandidates);
        uint256[] memory votes = new uint256[](numCandidates);
        
        for (uint256 i = 0; i < numCandidates; i++) {
            uint256 candidateId = election.candidateIds[i];
            names[i] = candidates[candidateId].name;
            votes[i] = candidates[candidateId].voteCount;
        }
        
        return (
            election.title,
            election.totalVotes,
            election.candidateIds,
            names,
            votes
        );
    }
    
    function getElectionInfo(uint256 _electionId) 
        public 
        view 
        electionExists(_electionId) 
        returns (
            string memory title,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            bool isActive,
            uint256 totalVotes
        ) 
    {
        Election storage election = elections[_electionId];
        return (
            election.title,
            election.description,
            election.startTime,
            election.endTime,
            election.isActive,
            election.totalVotes
        );
    }
    
    function getCandidateInfo(uint256 _candidateId) 
        public 
        view 
        returns (
            string memory name,
            string memory description,
            uint256 voteCount
        ) 
    {
        require(candidates[_candidateId].exists, "Candidate does not exist");
        Candidate storage candidate = candidates[_candidateId];
        return (candidate.name, candidate.description, candidate.voteCount);
    }
    
    function isElectionActive(uint256 _electionId) public view electionExists(_electionId) returns (bool) {
        Election storage election = elections[_electionId];
        return election.isActive && 
               block.timestamp >= election.startTime && 
               block.timestamp <= election.endTime;
    }
    
    function getWinner(uint256 _electionId) 
        public 
        view 
        electionExists(_electionId) 
        returns (
            uint256 winnerCandidateId,
            string memory winnerName,
            uint256 winningVoteCount
        ) 
    {
        Election storage election = elections[_electionId];
        require(!election.isActive || block.timestamp > election.endTime, "Election is still active");
        
        uint256 maxVotes = 0;
        uint256 winnerId = 0;
        
        for (uint256 i = 0; i < election.candidateIds.length; i++) {
            uint256 candidateId = election.candidateIds[i];
            if (candidates[candidateId].voteCount > maxVotes) {
                maxVotes = candidates[candidateId].voteCount;
                winnerId = candidateId;
            }
        }
        
        return (winnerId, candidates[winnerId].name, maxVotes);
    }
    
    function hasVoterVoted(uint256 _electionId, address _voter) 
        public 
        view 
        electionExists(_electionId) 
        returns (bool) 
    {
        return hasVoted[_electionId][_voter];
    }
}
