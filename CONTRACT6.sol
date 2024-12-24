// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MentorshipProgram {
    struct Mentor {
        string expertise;
        uint256 hourlyRate;
        bool isActive;
        uint256 rating;
        uint256 totalRatings;
    }

    struct Session {
        address mentor;
        address mentee;
        uint256 duration;
        uint256 totalCost;
        bool isCompleted;
        bool isPaid;
        string feedback;
        uint8 rating;
    }

    mapping(address => Mentor) public mentors;
    mapping(uint256 => Session) public sessions;
    mapping(address => uint256[]) public mentorSessions;
    mapping(address => uint256[]) public menteeSessions;
    
    uint256 public sessionCount;
    uint256 public platformFee = 5; // 5% platform fee

    event MentorRegistered(address indexed mentor, string expertise, uint256 hourlyRate);
    event SessionScheduled(uint256 indexed sessionId, address mentor, address mentee, uint256 duration);
    event SessionCompleted(uint256 indexed sessionId, string feedback, uint8 rating);
    event PaymentReleased(uint256 indexed sessionId, uint256 amount);

    modifier onlyMentor(uint256 _sessionId) {
        require(sessions[_sessionId].mentor == msg.sender, "Not the session mentor");
        _;
    }

    modifier onlyMentee(uint256 _sessionId) {
        require(sessions[_sessionId].mentee == msg.sender, "Not the session mentee");
        _;
    }

    function registerMentor(string memory _expertise, uint256 _hourlyRate) external {
        require(_hourlyRate > 0, "Invalid hourly rate");
        mentors[msg.sender] = Mentor({
            expertise: _expertise,
            hourlyRate: _hourlyRate,
            isActive: true,
            rating: 0,
            totalRatings: 0
        });
        
        emit MentorRegistered(msg.sender, _expertise, _hourlyRate);
    }

    function scheduleSession(address _mentor, uint256 _duration) external payable {
        require(mentors[_mentor].isActive, "Mentor not active");
        uint256 cost = (_duration * mentors[_mentor].hourlyRate);
        uint256 totalCost = cost + (cost * platformFee / 100);
        require(msg.value >= totalCost, "Insufficient payment");

        Session memory newSession = Session({
            mentor: _mentor,
            mentee: msg.sender,
            duration: _duration,
            totalCost: totalCost,
            isCompleted: false,
            isPaid: false,
            feedback: "",
            rating: 0
        });

        sessions[sessionCount] = newSession;
        mentorSessions[_mentor].push(sessionCount);
        menteeSessions[msg.sender].push(sessionCount);

        emit SessionScheduled(sessionCount, _mentor, msg.sender, _duration);
        sessionCount++;
    }

    function completeSession(uint256 _sessionId, string memory _feedback) external onlyMentor(_sessionId) {
        Session storage session = sessions[_sessionId];
        require(!session.isCompleted, "Session already completed");
        
        session.isCompleted = true;
        session.feedback = _feedback;
    }

    function rateAndRelease(uint256 _sessionId, uint8 _rating) external onlyMentee(_sessionId) {
        Session storage session = sessions[_sessionId];
        require(session.isCompleted, "Session not completed");
        require(!session.isPaid, "Payment already released");
        require(_rating >= 1 && _rating <= 5, "Invalid rating");

        session.rating = _rating;
        session.isPaid = true;

        // Update mentor rating
        Mentor storage mentor = mentors[session.mentor];
        mentor.rating = ((mentor.rating * mentor.totalRatings) + _rating) / (mentor.totalRatings + 1);
        mentor.totalRatings++;

        // Calculate and transfer payments
        uint256 platformAmount = (session.totalCost * platformFee) / 100;
        uint256 mentorAmount = session.totalCost - platformAmount;

        payable(session.mentor).transfer(mentorAmount);
        payable(address(this)).transfer(platformAmount);

        emit SessionCompleted(_sessionId, session.feedback, _rating);
        emit PaymentReleased(_sessionId, mentorAmount);
    }

    function updateHourlyRate(uint256 _newRate) external {
        require(_newRate > 0, "Invalid hourly rate");
        mentors[msg.sender].hourlyRate = _newRate;
    }

    function deactivateMentor() external {
        require(mentors[msg.sender].isActive, "Mentor already inactive");
        mentors[msg.sender].isActive = false;
    }

    function getMentorSessions(address _mentor) external view returns (uint256[] memory) {
        return mentorSessions[_mentor];
    }

    function getMenteeSessions(address _mentee) external view returns (uint256[] memory) {
        return menteeSessions[_mentee];
    }

    function getMentorDetails(address _mentor) external view returns (
        string memory expertise,
        uint256 hourlyRate,
        bool isActive,
        uint256 rating,
        uint256 totalRatings
    ) {
        Mentor memory mentor = mentors[_mentor];
        return (
            mentor.expertise,
            mentor.hourlyRate,
            mentor.isActive,
            mentor.rating,
            mentor.totalRatings
        );
    }
}