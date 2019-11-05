/*
需求1： Token管理
在以太坊公链创建Token，并实现ERC20协议
总量1依，不能增发、名称CI、单位CI、小数点6位
支持转账、被动转账、授权等基本功能
支持Token销毁
*/

pragma solidity >=0.4.22 <0.6.0;

contract TokenERC20 {

  string public name; //Token名称
  string public symbol; //Token单位
  uint8 public decimals; //小数点


  uint256 public totalSuppy; //总发行量

  //地址对应的Token
  mapping (address => uint256) public balanceOf;
  //授权使用
  mapping (address => mapping(address => uint256)) public approvalBanlance;

  //转账事件
  event Transfer(address from, address to, uint256 value);
  //授权事件
  event Approval(address from, address delegatee, uint256 value);
  //Token销毁事件
  event Destory(address destorys, uint256 value);

  //初始化参数
  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initiSuppy) public {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
    totalSuppy = _initiSuppy * 10 ** uint256(decimals);
    balanceOf[msg.sender] = totalSuppy;
  }


  //转账交易
  function _transfer(address _from, address _to, uint256 _value) internal {
    require(balanceOf[_from] >= _value); //地址拥有的Token必须大于等于需要转账的value
    require(_to != address(0x0));  //交易地址不能为空
    require(balanceOf[_to] + _value > balanceOf[_to]); //防止溢出

    uint256 previousBanlance = balanceOf[_from] + balanceOf[_to]; //校验
    balanceOf[_from] -= _value;
    balanceOf[_to] += _value;
    emit Transfer(_from, _to, _value);

    // 判断总额是否一致, 避免过程出错
    assert (balanceOf[_from] + balanceOf[_to] == previousBanlance);
  }

  //主动转账
  function transfer(address _to, uint256 _value) public {
    _transfer(msg.sender, _to, _value);
  }

  //被动转账
  function transferFrom(address _from, address _to, uint256 _value) public {
    require(approvalBanlance[_from][msg.sender] >= _value); //授权Token必须大于等于value
    approvalBanlance[_from][msg.sender] -= _value;
    _transfer(_from, _to, _value);
  }

  //授权
  function approval(address _delegatee, uint256 _value) public {
    require(balanceOf[msg.sender] >= _value); //地址拥有的Token必须大于等于需要转账的value
    approvalBanlance[msg.sender][_delegatee] = _value;
    emit Approval(msg.sender, _delegatee, _value);
  }

  //Token销毁
  function destory(uint _value) public {
    require(balanceOf[msg.sender] >= _value);
    balanceOf[msg.sender] -= _value;
    totalSuppy -= _value;
    emit Destory(msg.sender, _value);
  }

  //授权Token销毁
  function destoryFrom(address _from, uint _value) public {
    require(approvalBanlance[_from][msg.sender] >= _value);
    require(balanceOf[_from] >= _value);
    balanceOf[_from] -= _value;
    approvalBanlance[_from][msg.sender] -= _value;
    totalSuppy -= _value;
    emit Destory(msg.sender, _value);
  }

}



/*
需求2： 多重签名
需求1的基础上实现以下功能
社区挖矿地址（以下简称地址1）
临时地址（以下简称地址2）
签名者有A B C三位
账号（其实也是地址）A需要从地址1提取一笔CI Token到临时地址，经过B和C签名后，这笔Token即可转入临时地址
*/

contract MultiSignature is TokenERC20{
  address private owner; //合约创建者
  mapping(address => uint8) public signer; //经理，可以签名

  //交易信息块，用于丢进队列等待签名
  struct Transcation {
    address from; //发起人
    address to; //接收方
    uint256 amount; //交易数量
    uint8 signatureCounts; //签名数量
    mapping(address => uint8) signatures; //签名
  }

  uint256 constant MIN_SIGNATURE = 2; //最小签名数，只读

  uint8[] private pendingTranscation; //队列，用于存放交易信息块
  uint8 public transcationId;

  mapping(uint256 => Transcation) public transcations; //给每个交易信息块添加一个id

  //创建交易事件
  event CreateTranscation(
    address from,
    address to,
    uint256 amount,
    uint8 transcationId
    );

  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initiSuppy) public TokenERC20(
      _name, _symbol, _decimals, _initiSuppy * 10 ** uint256(_decimals)){
    owner = msg.sender;
    balanceOf[msg.sender] = totalSuppy;
  }

  modifier onlyOwner() {
    require(owner == msg.sender);
    _;
  }

  modifier onlySigner() {
    require(owner == msg.sender || signer[msg.sender] == 1);
    _;
  }

  //添加签名员
  function setSigner(address s) public onlyOwner {
     signer[s] = 1;
  }

  function removeSigner(address s) public onlyOwner {
      signer[s] = 0;
  }
  
  function() external payable {}
   
  //交易发起
  function startTransfer(address _to, uint256 _amount) public {
    require(_to != address(0x0));
    require(balanceOf[msg.sender] >= _amount);

    //转账到合约，等签名后在从合约转账给对应的地址
    _transfer(msg.sender, address(this), _amount);

    uint8 transcationid = transcationId++;
        
    Transcation memory transcation;
    transcation.from = msg.sender;
    transcation.to = _to;
    transcation.amount = _amount;
    transcation.signatureCounts = 0;
    transcations[transcationid] = transcation;
    
    
    pendingTranscation.push(transcationid);
    emit CreateTranscation(msg.sender, _to, _amount, transcationid);
  }

  //查看队列
  function getPendingTranscation() public view returns (uint) {
    return pendingTranscation.length;
  }
  
  //查看签名数
  function getCounts(uint8 id) public view returns (uint256) {
      return transcations[id].signatureCounts;
  }
  
  function getBalance() public view returns (uint256) {
      balanceOf[address(this)];
  }
 
  //签名
  function multiSignature(uint8 id) public onlySigner {
    Transcation storage transcation = transcations[id];
    require(transcation.from != address(0x0));
    require(msg.sender != transcation.from);
    require(transcation.signatures[msg.sender] != 1);

    transcation.signatures[msg.sender] = 1;
    transcation.signatureCounts++;

    if (transcation.signatureCounts >= MIN_SIGNATURE) {
      require(balanceOf[address(this)] >= transcation.amount);

      _transfer(address(this), transcation.to, transcation.amount);

      //交易成功，移除
      delete pendingTranscation;  //从队列中移除，节省内存
      delete transcations[id];
      
    }
  }

}

