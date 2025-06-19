
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Gaming Tournament Platform
 * @dev Smart contract for managing gaming tournaments with entry fees and prize distribution
 */
contract Project {
    address public owner;
    uint256 public tournamentCounter;
    
    struct Tournament {
        uint256 id;
        string name;
        uint256 entryFee;
        uint256 prizePool;
        uint256 maxParticipants;
        uint256 currentParticipants;
        address[] participants;
        address winner;
        bool isActive;
        bool isCompleted;
        uint256 startTime;
        uint256 endTime;
    }
    
    mapping(uint256 => Tournament) public tournaments;
    mapping(uint256 => mapping(address => bool)) public hasJoined;
    mapping(address => uint256) public playerWinnings;
    
    event TournamentCreated(uint256 indexed tournamentId, string name, uint256 entryFee, uint256 maxParticipants);
    event PlayerJoined(uint256 indexed tournamentId, address indexed player);
    event TournamentCompleted(uint256 indexed tournamentId, address indexed winner, uint256 prizeAmount);
    event PrizeWithdrawn(address indexed player, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier tournamentExists(uint256 _tournamentId) {
        require(_tournamentId <= tournamentCounter && _tournamentId > 0, "Tournament does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        tournamentCounter = 0;
    }
    
    /**
     * @dev Creates a new gaming tournament
     * @param _name Name of the tournament
     * @param _entryFee Entry fee required to join (in wei)
     * @param _maxParticipants Maximum number of participants allowed
     * @param _duration Duration of the tournament in seconds
     */
    function createTournament(
        string memory _name,
        uint256 _entryFee,
        uint256 _maxParticipants,
        uint256 _duration
    ) external onlyOwner {
        require(_maxParticipants > 1, "Tournament must allow at least 2 participants");
        require(_duration > 0, "Tournament duration must be greater than 0");
        
        tournamentCounter++;
        
        tournaments[tournamentCounter] = Tournament({
            id: tournamentCounter,
            name: _name,
            entryFee: _entryFee,
            prizePool: 0,
            maxParticipants: _maxParticipants,
            currentParticipants: 0,
            participants: new address[](0),
            winner: address(0),
            isActive: true,
            isCompleted: false,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration
        });
        
        emit TournamentCreated(tournamentCounter, _name, _entryFee, _maxParticipants);
    }
    
    /**
     * @dev Allows players to join a tournament by paying the entry fee
     * @param _tournamentId ID of the tournament to join
     */
    function joinTournament(uint256 _tournamentId) external payable tournamentExists(_tournamentId) {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.isActive, "Tournament is not active");
        require(!tournament.isCompleted, "Tournament has already ended");
        require(block.timestamp < tournament.endTime, "Tournament registration has closed");
        require(msg.value == tournament.entryFee, "Incorrect entry fee amount");
        require(!hasJoined[_tournamentId][msg.sender], "Already joined this tournament");
        require(tournament.currentParticipants < tournament.maxParticipants, "Tournament is full");
        
        tournament.participants.push(msg.sender);
        tournament.currentParticipants++;
        tournament.prizePool += msg.value;
        hasJoined[_tournamentId][msg.sender] = true;
        
        emit PlayerJoined(_tournamentId, msg.sender);
    }
    
    /**
     * @dev Completes a tournament and declares the winner
     * @param _tournamentId ID of the tournament to complete
     * @param _winner Address of the winning player
     */
    function completeTournament(uint256 _tournamentId, address _winner) external onlyOwner tournamentExists(_tournamentId) {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.isActive, "Tournament is not active");
        require(!tournament.isCompleted, "Tournament already completed");
        require(hasJoined[_tournamentId][_winner], "Winner must be a tournament participant");
        require(tournament.currentParticipants >= 2, "Tournament needs at least 2 participants");
        
        tournament.winner = _winner;
        tournament.isActive = false;
        tournament.isCompleted = true;
        
        // Calculate prize distribution (90% to winner, 10% platform fee)
        uint256 platformFee = (tournament.prizePool * 10) / 100;
        uint256 winnerPrize = tournament.prizePool - platformFee;
        
        playerWinnings[_winner] += winnerPrize;
        playerWinnings[owner] += platformFee;
        
        emit TournamentCompleted(_tournamentId, _winner, winnerPrize);
    }
    
    /**
     * @dev Allows players to withdraw their winnings
     */
    function withdrawWinnings() external {
        uint256 amount = playerWinnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");
        
        playerWinnings[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit PrizeWithdrawn(msg.sender, amount);
    }
    
    // View functions
    function getTournamentDetails(uint256 _tournamentId) external view tournamentExists(_tournamentId) returns (
        string memory name,
        uint256 entryFee,
        uint256 prizePool,
        uint256 maxParticipants,
        uint256 currentParticipants,
        address winner,
        bool isActive,
        bool isCompleted,
        uint256 startTime,
        uint256 endTime
    ) {
        Tournament storage tournament = tournaments[_tournamentId];
        return (
            tournament.name,
            tournament.entryFee,
            tournament.prizePool,
            tournament.maxParticipants,
            tournament.currentParticipants,
            tournament.winner,
            tournament.isActive,
            tournament.isCompleted,
            tournament.startTime,
            tournament.endTime
        );
    }
    
    function getTournamentParticipants(uint256 _tournamentId) external view tournamentExists(_tournamentId) returns (address[] memory) {
        return tournaments[_tournamentId].participants;
    }
    
    function getPlayerWinnings(address _player) external view returns (uint256) {
        return playerWinnings[_player];
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
