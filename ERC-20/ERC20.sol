// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/*   Contrato que sigue el estandar ERC-20   */

contract ERC20 {
    address public proxy;                                                       // Dirección proxy
    string public name;                                                         // Nombre del token
    string public symbol;                                                       // Siglas del token
    uint8 public decimals;                                                      // Número de decimales
    uint256 public totalSupply;                                                 // Total supply
    mapping(address => uint256) public balanceOf;                               // Tokens que posee cada cartera
    mapping(address => mapping(address => uint256)) public allowance;           // Cantidad de tokens que una cartera tiene permiso a usar de otra

    // Modificador para limitar una función al owner unicamente
    modifier onlyProxy {
        require(msg.sender == proxy);
        _;
    }

    constructor (address _proxy){
        proxy = _proxy;
        name = "TIXS";
        symbol = "TIX";
        decimals = 4;
        //La blockchain no utiliza decimales
        totalSupply = 100000000000000 * (uint256(10) ** decimals);
        balanceOf[msg.sender] = totalSupply;
    }

    /*  Eventos   */
    event Tranfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /*  Funciones   */

    // Función para transferir fondos entre direcciones
    function transfer (address _to, uint256 _value) public returns(bool success)        
    {           
        require(balanceOf[msg.sender] >= _value,"Transfer Error: you haven't enought coins");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Tranfer(msg.sender,_to, _value);
        return true;

    }

    // Función para aprobar que otra dirección use una cantidad de mis fondos
    function approve(address _spender, uint256 _value) public returns (bool successs){
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;

    }

    // Función para transferir fondos de una dirección en la cual estoy autorizado a otra
    function transferFrom (address _from, address _to, uint256 _value) public returns(bool){
        require(balanceOf[_from] >= _value, "TransferFrom Error: the address hasn't enought coins");
        require(allowance[_from][msg.sender]>= _value, "TransferFrom Error: you don't have permissions for this amount of coins.");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        
        emit Tranfer(_from,_to, _value);
        return true;

    }

    function transferProxy(address _from, address _to, uint256 _value) public onlyProxy returns(bool){
        require(balanceOf[_from] >= _value, "TransferFrom Error: the address hasn't enought coins");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Tranfer(_from,_to, _value);
        return true;
    }

} 

