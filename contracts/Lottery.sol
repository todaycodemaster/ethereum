pragma solidity ^0.6.6;
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import {randomness_interface} from "./interfaces/randomness_interface.sol";
import {governance_interface} from "./interfaces/governance_interface.sol";

contract Lottery is ChainlinkClient {
    enum LOTTERY_STATE { OPEN, CLOSED, CALCULATING_WINNER }
    LOTTERY_STATE public lottery_state;
    uint256 public lotteryId;
    address payable[] public players;
    governance_interface public governance;
    // .01 ETH
    uint256 public MINIMUM = 1000000000000000;
    // 0.1 LINK
    uint256 public ORACLE_PAYMENT = 100000000000000000;
    // Alarm stuff
    address CHAINLINK_ALARM_ORACLE = 0xB36d3709e22F7c708348E225b20b13eA546E6D9c;
    bytes32 CHAINLINK_ALARM_JOB_ID = "de6ad2f87c6b42679777dc658a93705c";
    
    constructor(address _governance) public
    {
        setPublicChainlinkToken();
        lotteryId = 1;
        lottery_state = LOTTERY_STATE.CLOSED;
        governance = governance_interface(_governance);
    }

    function enter() public payable {
        assert(msg.value == MINIMUM);
        assert(lottery_state == LOTTERY_STATE.OPEN);
        players.push(msg.sender);
    } 
    
  function start_new_lottery(uint256 duration) public {
    require(lottery_state == LOTTERY_STATE.CLOSED, "can't start a new lottery yet");
    lottery_state = LOTTERY_STATE.OPEN;
    Chainlink.Request memory req = buildChainlinkRequest(CHAINLINK_ALARM_JOB_ID, address(this), this.fulfill_alarm.selector);
    req.addUint("until", now + duration);
    sendChainlinkRequestTo(CHAINLINK_ALARM_ORACLE, req, ORACLE_PAYMENT);
  }
  
  function fulfill_alarm(bytes32 _requestId)
    public
    recordChainlinkFulfillment(_requestId)
      {
        require(lottery_state == LOTTERY_STATE.OPEN, "The lottery hasn't even started!");
        // add a require here so that only the oracle contract can
        // call the fulfill alarm method
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        lotteryId = lotteryId + 1;
        pickWinner();
    }


    function pickWinner() private {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "You aren't at that stage yet!");
        randomness_interface(governance.randomness()).getRandom(lotteryId, lotteryId);
        //this kicks off the request and returns through fulfill_random
    }
    
    function fulfill_random(uint256 randomness) external {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "You aren't at that stage yet!");
        require(randomness > 0, "random-not-found");
        // assert(msg.sender == governance.randomness());
        uint256 index = randomness % players.length;
        players[index].transfer(address(this).balance);
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        // You could have this run forever
        // start_new_lottery();
        // or with a cron job from a chainlink node would allow you to 
        // keep calling "start_new_lottery" as well
    }

    function get_players() public view returns (address payable[] memory) {
        return players;
    }
    
    function get_pot() public view returns(uint256){
        return address(this).balance;
    }
}
