use starknet::{ContractAddress, get_caller_address};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_prank, stop_prank};
use array::ArrayTrait;
use ai_prediction_market_contracts::IAIPredictionMarketDispatcher;
use ai_prediction_market_contracts::IAIPredictionMarketDispatcherTrait;
use ai_prediction_market_contracts::MarketDetails;
use ai_prediction_market_contracts::BetDetails;
use ai_prediction_market_contracts::AIAgentDetails;

const ADMIN_ROLE: felt252 = 1;
const ORACLE_ROLE: felt252 = 2;

fn deploy_contract(admin: ContractAddress) -> ContractAddress {
    let contract = declare("AIPredictionMarket").unwrap().contract_class();
    let constructor_args = array![admin.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

#[test]
fn test_add_liquidity() {
    let admin = starknet::contract_address_const::<1>();
    let contract_address = deploy_contract(admin);
    let dispatcher = IAIPredictionMarketDispatcher { contract_address };
    
    // Test adding liquidity
    let amount: u256 = 1000;
    start_prank(contract_address, admin);
    dispatcher.add_liquidity(amount);
    
    let total_liquidity = dispatcher.get_total_liquidity();
    assert(total_liquidity == amount, 'Invalid liquidity amount');
    stop_prank(contract_address);
}

#[test]
#[should_panic(expected: ('Invalid amount',))]
fn test_add_zero_liquidity() {
    let admin = starknet::contract_address_const::<1>();
    let contract_address = deploy_contract(admin);
    let dispatcher = IAIPredictionMarketDispatcher { contract_address };
    
    start_prank(contract_address, admin);
    dispatcher.add_liquidity(0);
    stop_prank(contract_address);
}

#[test]
fn test_create_market() {
    let admin = starknet::contract_address_const::<1>();
    let contract_address = deploy_contract(admin);
    let dispatcher = IAIPredictionMarketDispatcher { contract_address };
    
    start_prank(contract_address, admin);
    
    let name: felt252 = 'Test Market';
    let market_type: u8 = 1;
    let mut prediction_parameters = ArrayTrait::new();
    prediction_parameters.append('param1');
    let deadline: u64 = 1735689600; // Future timestamp
    let min_stake: u256 = 100;
    let max_stake: u256 = 1000;
    
    dispatcher.create_market(
        name,
        market_type,
        prediction_parameters,
        deadline,
        min_stake,
        max_stake
    );
    
    let market_details = dispatcher.get_market_details(0);
    assert(market_details.name == name, 'Invalid market name');
    assert(market_details.market_type == market_type, 'Invalid market type');
    assert(market_details.min_stake == min_stake, 'Invalid min stake');
    assert(market_details.max_stake == max_stake, 'Invalid max stake');
    assert(!market_details.is_closed, 'Market should be open');
    
    stop_prank(contract_address);
}

#[test]
fn test_place_bet() {
    let admin = starknet::contract_address_const::<1>();
    let user = starknet::contract_address_const::<2>();
    let contract_address = deploy_contract(admin);
    let dispatcher = IAIPredictionMarketDispatcher { contract_address };
    
    // Setup market
    start_prank(contract_address, admin);
    let mut prediction_parameters = ArrayTrait::new();
    dispatcher.create_market(
        'Test Market',
        1,
        prediction_parameters,
        1735689600,
        100,
        1000
    );
    
    // Add liquidity
    dispatcher.add_liquidity(10000);
    stop_prank(contract_address);
    
    // Place bet
    start_prank(contract_address, user);
    dispatcher.place_bet(0, 500, 1);
    
    let bet_details = dispatcher.get_market_stats(0);
    assert(bet_details.stake == 500, 'Invalid stake amount');
    assert(bet_details.predicted_outcome == 1, 'Invalid prediction');
    stop_prank(contract_address);
}

#[test]
fn test_register_ai_agent() {
    let admin = starknet::contract_address_const::<1>();
    let agent = starknet::contract_address_const::<2>();
    let contract_address = deploy_contract(admin);
    let dispatcher = IAIPredictionMarketDispatcher { contract_address };
    
    start_prank(contract_address, admin);
    dispatcher.register_ai_agent(agent, 'test_credentials');
    
    let agent_details = dispatcher.get_ai_agent_details(agent);
    assert(agent_details.is_verified, 'Agent should be verified');
    assert(agent_details.reputation == 100, 'Invalid initial reputation');
    assert(agent_details.credentials == 'test_credentials', 'Invalid credentials');
    stop_prank(contract_address);
}

#[test]
#[should_panic(expected: ('Market expired',))]
fn test_place_bet_expired_market() {
    let admin = starknet::contract_address_const::<1>();
    let user = starknet::contract_address_const::<2>();
    let contract_address = deploy_contract(admin);
    let dispatcher = IAIPredictionMarketDispatcher { contract_address };
    
    // Create market with past deadline
    start_prank(contract_address, admin);
    let mut prediction_parameters = ArrayTrait::new();
    dispatcher.create_market(
        'Test Market',
        1,
        prediction_parameters,
        0, // Past timestamp
        100,
        1000
    );
    stop_prank(contract_address);
    
    // Attempt to place bet
    start_prank(contract_address, user);
    dispatcher.place_bet(0, 500, 1);
    stop_prank(contract_address);
}