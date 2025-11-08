pragma solidity ^0.8.0;
contract ProductTracking {
    address public owner;
    enum Role { None, Manufacturer, Warehouse, Wholesaler, Distributor }
    struct Entity {
        string name;
        Role role;
        bool isRegistered;
    }
    struct Product {
        uint id;
        string name;
        string currentLocation;
        string status;
        uint timestamp;
        address currentOwner;
    }

    mapping(address => Entity) public entities;
    mapping(uint => Product) public products;
    uint public productCount = 0;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can execute");
        _;
    }

    modifier onlyRegistered() {
        require(entities[msg.sender].isRegistered == true, "Only registered entities allowed");
        _;
    }

    modifier onlyRole(Role _role) {
        require(entities[msg.sender].role == _role, "Not authorized for this action");
        _;
    }

    event EntityRegistered(address entity, string name, Role role);
    event ProductCreated(uint productId, string name, address manufacturer);
    event ProductUpdated(uint productId, string status, string location, address updatedBy);

    constructor() {
        owner = msg.sender;
        entities[owner] = Entity("Owner", Role.None, true);
    }

    // Owner registers entities with roles
    function registerEntity(address _entity, string memory _name, Role _role) public onlyOwner {
        require(_role != Role.None, "Invalid role");
        entities[_entity] = Entity(_name, _role, true);
        emit EntityRegistered(_entity, _name, _role);
    }

    // Manufacturer creates product
    function createProduct(string memory _name, string memory _location, string memory _status) public onlyRole(Role.Manufacturer) {
        productCount++;
        products[productCount] = Product(productCount, _name, _location, _status, block.timestamp, msg.sender);
        emit ProductCreated(productCount, _name, msg.sender);
    }

    // Update product status/location, only allowed for registered entities
    function updateProduct(uint _productId, string memory _status, string memory _location) public onlyRegistered {
        require(_productId > 0 && _productId <= productCount, "Invalid product ID");

        Product storage product = products[_productId];

        Role senderRole = entities[msg.sender].role;
        require(
            senderRole == Role.Manufacturer ||
            senderRole == Role.Warehouse ||
            senderRole == Role.Wholesaler ||
            senderRole == Role.Distributor,
            "Unauthorized role"
        );

        product.status = _status;
        product.currentLocation = _location;
        product.timestamp = block.timestamp;
        product.currentOwner = msg.sender;

        emit ProductUpdated(_productId, _status, _location, msg.sender);
    }

    // Get product details
    function getProduct(uint _productId) public view returns (
        uint id,
        string memory name,
        string memory currentLocation,
        string memory status,
        uint timestamp,
        address currentOwner
    ) {
        Product memory product = products[_productId];
        return (
            product.id,
            product.name,
            product.currentLocation,
            product.status,
            product.timestamp,
            product.currentOwner
        );
    }

    // Get entity details
    function getEntity(address _entity) public view returns (string memory name, Role role, bool isRegistered) {
        Entity memory entity = entities[_entity];
        return (entity.name, entity.role, entity.isRegistered);
    }
}
