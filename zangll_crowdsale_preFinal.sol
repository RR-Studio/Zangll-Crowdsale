pragma solidity ^0.4.16;

library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

interface Zangll    {

    function balanceOf(address who) public constant returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function allowance(address owner, address spender) public constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);

}

interface MyFiatContract {
    function GetPrice() constant returns (uint);
}

contract Ownable {

  address public owner;



  function Ownable() {
    owner = msg.sender;
  }


  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) onlyOwner {
    require(newOwner != address(0));
    owner = newOwner;
  }

}

contract CrowdsaleZangll is Ownable {
  mapping(address => uint256) purchases;  // сколько токенов купили на данный адрес
  MyFiatContract public MyPrice;
  event Debug (string message);
  event TokenPurchased(address purchaser, uint256 value, uint amount);
  event ContractPaused(uint time);
  event ContractPauseOff(uint time);
  event ContractEnded(uint time);
  //event LowTokensOnContract(uint amount);


    using SafeMath for uint;

    address multisig;         //тот кому идут эфиры (creator of contract)

    //uint restrictedPercent;

    //address restricted;




    Zangll token = Zangll(0x632E15775Acb67303178aa8b08A26ba594f18D84);

    uint start;   // start of CrowdsaleZangll

    uint period;    // period of sale

    uint priceInCents;

    uint256 ETHUSD ;    // how many USD cents in 1 ETH

    uint256 purchaseCap; // max purchase for a single address

    uint256 public totalPurchased;  // total tokens purchased on crowdsale PUBLIC!!!

    uint256 maxPurchase; // max tokens to crowdsale

    bool public pause;
    bool public end;
    //uint32 public bonusPercent = 0;

    // function bonusChange(uint32 newBonusPercent) {
    //     uint32 bonusPercent = newBonusPercent;
    // }

    function changeOracul(address newOracle) onlyOwner {
      MyPrice = MyFiatContract(newOracle);
    }

    function CrowdsaleZangll() {

      ETHUSD = MyPrice.GetPrice();
      multisig = msg.sender;

      priceInCents = 27;    // price in USD cents for 1 token
      start = 1511047218;   // 19 ноября 2.20 утра 2017
      period = 28;
      purchaseCap = 3000000 * 10 ** 18;  // 3_000_000 tokens to one address
      totalPurchased = 0;
      maxPurchase = 140000000 * 10 ** 18; // 140_000_000 tokens sales on crowdsale
      Debug("crowdsale inits");
      pause = false;
      end = false;
    }

    function purchasesOf(address purchaser) public constant returns (uint256 value) {
      return purchases[purchaser];
    }

    modifier saleIsOn() {
      require(now > start && now < start + period * 1 days);
      require(totalPurchased <= maxPurchase);
      require(pause == false);
      require(end == false);
      _;
    }

    modifier isPaused() {
      require(pause == true);
      _;
    }

    function setPauseOn() onlyOwner saleIsOn {
      pause = true;
      ContractPaused(now);
    }

    function setPauseOff() onlyOwner isPaused {
      pause = false;
      ContractPauseOff(now);
    }

    function endCrowdsale(uint code) onlyOwner {
      uint password = 1234561;
      require(password == code);
      end = true;
      ContractEnded(now);
    }
    /*
    посылая 1 эфир инвестор получает 30000 центов = 30_000 / 27
    */

    function createTokens() saleIsOn payable {

      require(purchases[msg.sender] < purchaseCap);     // не купил ли на 3 млн уже
      //uint tokens = rate.mul(msg.value).div(1 ether);
      uint tokens = msg.value.mul(ETHUSD).div(priceInCents);  // вычисление токенов за присланный эфир
      uint bonusTokens = 0;
        // uint bonusTokens = tokens.mul(bonusPercent).div(100);
      Debug("base tokens = " + string(tokens));
      if(now < start + 1 hours ) {                    //1 hour
        bonusTokens = tokens.mul(35).div(100);
      } else if(now >= start + 1 hours && now < start + 1 days) {   //1 day
        bonusTokens = tokens.mul(30).div(100);
      } else if(now >= start + 1 days && now < start + 2 days) { // 2 day
        bonusTokens = tokens.mul(25).div(100);
      } else if(now >= start + 2 days && now < start + 1 weeks) {   //1 week
        bonusTokens = tokens.mul(20).div(100);
      } else if(now >= start + 1 weeks && now < start + 2 weeks) {  //2 weeks
        bonusTokens = tokens.mul(15).div(100);
      } else if(now >= start + 2 weeks && now < start + 3 weeks) {    // 3 week
        bonusTokens = tokens.mul(10).div(100);
      }
      uint tokensWithBonus = tokens.add(bonusTokens);

      require(token.balanceOf(this) >= tokensWithBonus);
      require(purchases[msg.sender] + tokensWithBonus <= purchaseCap);
      require(maxPurchase >= totalPurchased + tokensWithBonus); //
      Debug("total tokens = " + string(tokensWithBonus));
      TokenPurchased(msg.sender, msg.value, tokensWithBonus);  // ивент покупки токенов (покупатель, цена в эфирах, кол-во токенов)
      purchases[msg.sender] = purchases[msg.sender].add(tokensWithBonus);     // записать на адрес сумму купленных токенов
      totalPurchased = totalPurchased.add(tokensWithBonus);        // суммировать все купленные токены
      multisig.transfer(msg.value);           // перевод создателю всего эфира
      token.transfer(msg.sender, tokensWithBonus);    // контракт с себя переводит токены инвестору
    }

  function() external payable {
    createTokens();
  }

}
