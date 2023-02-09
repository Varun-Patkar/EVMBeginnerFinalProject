// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
/// @title Voting with delegation.
contract Ballot {
    // This declares a new complex type which will
    // be used for variables later.
    // It will represent a single voter.
    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to (GIVE VOTE POWER TO)
        uint vote;   // index of the voted proposal
    }

    // This is a type for a single proposal.
    struct Proposal { //LIKE A CANDIDATE
        bytes32 name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    address public chairperson;

    // This declares a state variable that
    // stores a `Voter` struct for each possible address.
    mapping(address => Voter) public voters;

    // A dynamically-sized array of `Proposal` structs.
    Proposal[] public proposals;

    /// Create a new ballot to choose one of `proposalNames`.
    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;//CHAIRPERSON IS THE PERSON WHO DEPLOYED CONTRACT
        voters[chairperson].weight = 1;//SET WEIGHT OF CHAIRPERSON VOTER OBJECT TO 1

        // For each of the provided proposal names,
        // create a new proposal object and add it
        // to the end of the array.
        for (uint i = 0; i < proposalNames.length; i++) {//CREATE PROPOSAL STRUCT OBJECTS FOR EACH PROPOSAL NAME
            // `Proposal({...})` creates a temporary
            // Proposal object and `proposals.push(...)`
            // appends it to the end of `proposals`.
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    // Give `voter` the right to vote on this ballot.
    // May only be called by `chairperson`.
    function giveRightToVote(address voter) external {
        // If the first argument of `require` evaluates
        // to `false`, execution terminates and all
        // changes to the state and to Ether balances
        // are reverted.
        // This used to consume all gas in old EVM versions, but
        // not anymore.
        // It is often a good idea to use `require` to check if
        // functions are called correctly.
        // As a second argument, you can also provide an
        // explanation about what went wrong.
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );//IF SENDER IS NOT CHAIRPERSON, THROW ERROR AS ONLY CHAIRPERSON CAN GIVE RIGHT TO VOTE TO A VOTER
        require(
            !voters[voter].voted,
            "The voter already voted."
        );//THEN CHECK IF THE VOTER HAS ALREADY VOTED, IF SO THROW ERROR
        require(voters[voter].weight == 0);//THEN CHECK IF THE VOTER HAS 0 WEIGHT, IF SO SET WEIGHT TO 1
        voters[voter].weight = 1;
    }

    /// Delegate your vote to the voter `to`.
    function delegate(address to) external {//BASICALLY GIVING VOTE TO ANOTHER PERSON SPECIFIED IN "to". BASICALLY A GROUP OF PEOPLE CAN DELEGATE THEIR VOTES 
        // assigns reference                //AND THEY WILL VOTE FOR THEM
        Voter storage sender = voters[msg.sender];//GET THE VOTER OBJECT OF THE SENDER IN STORAGE SO CHANGES MADE WILL BE CARRIED OVER IN THE CONTRACT
        require(!sender.voted, "You already voted.");//CHECK IF VOTER HAS ALREADY VOTED(SO CAN'T GIVE HIS POWER), IF SO THROW ERROR

        require(to != msg.sender, "Self-delegation is disallowed.");//CHECK IF VOTER IS GIVING VOTE POWER TO HIMSELF, IF SO THROW ERROR

        // Forward the delegation as long as
        // `to` also delegated.
        // In general, such loops are very dangerous,
        // because if they run too long, they might
        // need more gas than is available in a block.
        // In this case, the delegation will not be executed,
        // but in other situations, such loops might
        // cause a contract to get "stuck" completely.
        while (voters[to].delegate != address(0)) {//CHECK IF THERE'S A LOOP IN VOTING(I GIIVE YOU MINE, YOU GIVE ME YOURS), IF SO THROW ERROR.
            to = voters[to].delegate;              //address(0) IS BURN ADDRESS(NOT RETRIEVABLE). DEFAULT SOLIDITY VALUE OF ADDRESS

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }

        // Since `sender` is a reference, this
        // modifies `voters[msg.sender].voted`
        Voter storage delegate_ = voters[to];//GET VOTER OBJECT FROM ADDRESS

        // Voters cannot delegate to wallets that cannot vote.
        require(delegate_.weight >= 1);//CHECK IF THE PERSON WHO IS BEING DELEGATED TO CAN VOTE THEMSELF\
                                       //IF NOT THEN NO POINT IN DELEGATING TO THEM
        sender.voted = true;//SET VOTED TO TRUE AND VOTED TO AS THE SPECIFIED PERSON
        sender.delegate = to;
        if (delegate_.voted) {//IF DELEGATOR HAS ALREADY VOTED, ADD TO HIS VOTE COUNT
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {//IF NOT THEN ADD TO HIS WEIGHT
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /// Give your vote (including votes delegated to you)
    /// to proposal `proposals[proposal].name`.
    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];//GET THE SENDER OBJECT IN STORAGE
        require(sender.weight != 0, "Has no right to vote");//CHECK IF HAS RIGHT TO VOTE
        require(!sender.voted, "Already voted.");//CHECK IF ALREADY VOTED
        sender.voted = true;//SET VOTED TO TRUE AND SET VOTE TO THE SPECIFIED PROPOSAL NO
        sender.vote = proposal;

        // If `proposal` is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[proposal].voteCount += sender.weight;//ADD TO VOTE COUNT
    }

    /// @dev Computes the winning proposal taking all
    /// previous votes into account.
    function winningProposal() public view
            returns (uint winningProposal_)//PUBLIC SO CAN BE ACCESSED ANYWHERE AND NO CHANGES TO CONTRACT SO VIEW
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {//GO OVER PROPOSALS AND FIND THE MAX ONE AND RETURN IT
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    // Calls winningProposal() function to get the index
    // of the winner contained in the proposals array and then
    // returns the name of the winner
    function winnerName() external view
            returns (bytes32 winnerName_)
    {//GET THE NUMBER OF MAX FROM ABOVE FUNCTION AND GET THEIR NAME AND RETURN IT
        winnerName_ = proposals[winningProposal()].name;
    }
}