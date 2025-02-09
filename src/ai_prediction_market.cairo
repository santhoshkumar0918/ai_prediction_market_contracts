use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use array::ArrayTrait;
use option::OptionTrait;
use traits::Into;
use zeroable::Zeroable;
use starknet::storage::Map;

// Storage types and mappings
#[derive(Drop, Serde, Copy)]
struct MarketDetails {
    name: felt252,
    market_type: u8,
    prediction_parameters: Array<felt252>,
    deadline: u64,
    min_stake: u256,
    max_stake: u256,
    is_closed: bool
}

#[derive(Drop, Serde, Copy)]
struct BetDetails {
    stake: u256,
    odds: u256,
    predicted_outcome: u32
}

#[derive(Drop, Serde, Copy)]
struct AIAgentDetails {
    is_verified: bool,
    reputation: u256,
    credentials: felt252
}

#[derive(Drop, Serde, Copy)]
struct AIAnalysis {
    confidence_score: u256,
    analysis_data: Array<felt252>
}

#[derive(Drop, Serde, Copy)]
struct RobotForecast {
    efficiency_score: u256,
    forecast_data: Array<felt252>
}

#[starknet::interface]
trait IAIPredictionMarket<TContractState> {
    // Core liquidity functions
    fn add_liquidity(ref self: TContractState, amount: u256);
    fn remove_liquidity(ref self: TContractState, amount: u256);
    
    // Market management functions
    fn create_market(
        ref self: TContractState, 
        name: felt252, 
        market_type: u8,
        prediction_parameters: Array<felt252>,
        deadline: u64,
        min_stake: u256,
        max_stake: u256
    );
    fn close_market(ref self: TContractState, market_id: u32);
    fn place_bet(ref self: TContractState, market_id: u32, stake: u256, predicted_outcome: u32);
    fn resolve_market(ref self: TContractState, market_id: u32, winning_outcome: u32);
    fn claim_reward(ref self: TContractState, market_id: u32);
    
    // AI agent management
    fn register_ai_agent(ref self: TContractState, agent_address: ContractAddress, credentials: felt252);
    fn update_ai_agent_reputation(ref self: TContractState, agent_address: ContractAddress, reputation_score: u256);
    fn submit_ai_analysis(
        ref self: TContractState,
        market_id: u32,
        confidence_score: u256,
        analysis_data: Array<felt252>
    );
    
    // Supply chain and robotics specific functions
    fn update_supply_metrics(ref self: TContractState, market_id: u32, metrics: Array<u256>);
    fn update_robot_forecast(
        ref self: TContractState,
        market_id: u32,
        robot_id: felt252,
        efficiency_score: u256,
        forecast_data: Array<felt252>
    );
    
    // Query functions
    fn get_market_details(self: @TContractState, market_id: u32) -> MarketDetails;
    fn get_ai_analysis(self: @TContractState, market_id: u32) -> AIAnalysis;
    fn get_supply_metrics(self: @TContractState, market_id: u32) -> Array<u256>;
    fn get_robot_efficiency_forecast(self: @TContractState, market_id: u32, robot_id: felt252) -> RobotForecast;
    fn get_ai_agent_details(self: @TContractState, agent_address: ContractAddress) -> AIAgentDetails;
    fn get_total_liquidity(self: @TContractState) -> u256;
    fn get_market_stats(self: @TContractState, market_id: u32) -> BetDetails;
}

#[starknet::contract]
mod AIPredictionMarket {
    use super::IAIPredictionMarket;
    use super::{MarketDetails, BetDetails, AIAgentDetails, AIAnalysis, RobotForecast};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use array::ArrayTrait;
    use option::OptionTrait;
    use traits::Into;
    use zeroable::Zeroable;
    use starknet::storage::Map;

    const ADMIN_ROLE: felt252 = 1;
    const ORACLE_ROLE: felt252 = 2;
    const MIN_CONFIDENCE_SCORE: u256 = 50;
    const MAX_REPUTATION_SCORE: u256 = 100;
    const BASE_REWARD_MULTIPLIER: u256 = 100;

    #[storage]
    struct Storage {
        total_liquidity_pool: u256,
        next_market_id: u32,
        roles: Map<(ContractAddress, felt252), bool>,
        market_details: Map<u32, MarketDetails>,
        market_bets: Map<(u32, ContractAddress), BetDetails>,
        market_outcomes: Map<u32, u32>,
        market_total_stakes: Map<u32, u256>,
        rewards_claimed: Map<(u32, ContractAddress), bool>,
        liquidity_provider_stakes: Map<ContractAddress, u256>,
        ai_agents: Map<ContractAddress, AIAgentDetails>,
        ai_analyses: Map<u32, AIAnalysis>,
        supply_metrics: Map<u32, Array<u256>>,
        robot_forecasts: Map<(u32, felt252), RobotForecast>,
        market_risk_scores: Map<u32, u256>,
        circuit_breaker_triggered: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MarketCreated: MarketCreated,
        BetPlaced: BetPlaced,
        MarketResolved: MarketResolved,
        RewardClaimed: RewardClaimed,
        LiquidityAdded: LiquidityAdded,
        LiquidityRemoved: LiquidityRemoved,
        AIAgentRegistered: AIAgentRegistered,
        AIAnalysisSubmitted: AIAnalysisSubmitted,
        SupplyMetricsUpdated: SupplyMetricsUpdated,
        RobotForecastUpdated: RobotForecastUpdated,
        CircuitBreakerTriggered: CircuitBreakerTriggered
    }

    #[derive(Drop, starknet::Event)]
    struct MarketCreated {
        market_id: u32,
        creator: ContractAddress,
        market_type: u8,
        deadline: u64
    }

    #[derive(Drop, starknet::Event)]
    struct BetPlaced {
        market_id: u32,
        user: ContractAddress,
        stake: u256,
        predicted_outcome: u32
    }

    #[derive(Drop, starknet::Event)]
    struct MarketResolved {
        market_id: u32,
        winning_outcome: u32
    }

    #[derive(Drop, starknet::Event)]
    struct RewardClaimed {
        market_id: u32,
        user: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityAdded {
        provider: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityRemoved {
        provider: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct AIAgentRegistered {
        agent: ContractAddress,
        credentials: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct AIAnalysisSubmitted {
        market_id: u32,
        agent: ContractAddress,
        confidence_score: u256
    }

    #[derive(Drop, starknet::Event)]
    struct SupplyMetricsUpdated {
        market_id: u32,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct RobotForecastUpdated {
        market_id: u32,
        robot_id: felt252,
        efficiency_score: u256
    }

    #[derive(Drop, starknet::Event)]
    struct CircuitBreakerTriggered {
        timestamp: u64,
        reason: felt252
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.roles.write((admin, ADMIN_ROLE), true);
        self.next_market_id.write(0);
        self.total_liquidity_pool.write(0);
        self.circuit_breaker_triggered.write(false);
    }

    #[abi(embed_v0)]
    impl AIPredictionMarketImpl of IAIPredictionMarket<ContractState> {
        fn add_liquidity(ref self: ContractState, amount: u256) {
            assert!(!self.circuit_breaker_triggered.read(), "Circuit breaker active");
            assert!(amount > 0, "Invalid amount");
            
            let caller = get_caller_address();
            self.total_liquidity_pool.write(self.total_liquidity_pool.read() + amount);
            self.liquidity_provider_stakes.write(
                caller,
                self.liquidity_provider_stakes.read(caller) + amount
            );
            
            self.emit(Event::LiquidityAdded(LiquidityAdded { provider: caller, amount }));
        }

        fn remove_liquidity(ref self: ContractState, amount: u256) {
            assert!(!self.circuit_breaker_triggered.read(), "Circuit breaker active");
            let caller = get_caller_address();
            let current_stake = self.liquidity_provider_stakes.read(caller);
            assert!(current_stake >= amount, "Insufficient stake");
            
            self.total_liquidity_pool.write(self.total_liquidity_pool.read() - amount);
            self.liquidity_provider_stakes.write(caller, current_stake - amount);
            
            self.emit(Event::LiquidityRemoved(LiquidityRemoved { provider: caller, amount }));
        }

        fn create_market(
            ref self: ContractState,
            name: felt252,
            market_type: u8,
            prediction_parameters: Array<felt252>,
            deadline: u64,
            min_stake: u256,
            max_stake: u256
        ) {
            assert!(!self.circuit_breaker_triggered.read(), "Circuit breaker active");
            assert!(market_type >= 1 && market_type <= 3, "Invalid market type");
            assert!(deadline > get_block_timestamp(), "Invalid deadline");
            assert!(min_stake > 0 && max_stake > min_stake, "Invalid stakes");
            
            let market_id = self.next_market_id.read();
            let _market_details = MarketDetails {
                name,
                market_type,
                prediction_parameters,
                deadline,
                min_stake,
                max_stake,
                is_closed: false
            };
            
            self.market_details.write(market_id, market_details);
            self.next_market_id.write(market_id + 1);
            
            self.emit(Event::MarketCreated(MarketCreated {
                market_id,
                creator: get_caller_address(),
                market_type,
                deadline
            }));
        }

        fn close_market(ref self: ContractState, market_id: u32) {
            let caller = get_caller_address();
            assert!(self.roles.read((caller, ADMIN_ROLE)), "Admin only");
            
            let mut market_details = self.market_details.read(market_id);
            market_details.is_closed = true;
            self.market_details.write(market_id, market_details);
        }

        fn place_bet(ref self: ContractState, market_id: u32, stake: u256, predicted_outcome: u32) {
            assert!(!self.circuit_breaker_triggered.read(), "Circuit breaker active");
            
            let market_details = self.market_details.read(market_id);
            assert!(!market_details.is_closed, "Market is closed");
            assert!(get_block_timestamp() < market_details.deadline, "Market expired");
            assert!(stake >= market_details.min_stake && stake <= market_details.max_stake, "Invalid stake amount");
            
            let caller = get_caller_address();
            let odds = self.calculate_odds(market_id, stake);
            
            let bet_details = BetDetails {
                stake,
                odds,
                predicted_outcome
            };
            
            self.market_bets.write((market_id, caller), bet_details);
            self.market_total_stakes.write(
                market_id,
                self.market_total_stakes.read(market_id) + stake
            );
            
            self.emit(Event::BetPlaced(BetPlaced {
                market_id,
                user: caller,
                stake,
                predicted_outcome
            }));
            
            // Check risk thresholds
            self.check_risk_thresholds(market_id);
        }

        fn resolve_market(ref self: ContractState, market_id: u32, winning_outcome: u32) {
            let caller = get_caller_address();
            assert!(self.roles.read((caller, ADMIN_ROLE)), "Admin only");
            
            let market_details = self.market_details.read(market_id);
            assert!(!market_details.is_closed, "Market already closed");
            assert!(get_block_timestamp() >= market_details.deadline, "Market not expired");
            
            self.market_outcomes.write(market_id, winning_outcome);
            self.close_market(market_id);
            
            self.emit(Event::MarketResolved(MarketResolved {
                market_id,
                winning_outcome
            }));
        }

        fn claim_reward(ref self: ContractState, market_id: u32) {
            let caller = get_caller_address();
            assert!(!self.rewards_claimed.read((market_id, caller)), "Already claimed");
            
            let winning_outcome = self.market_outcomes.read(market_id);
            let bet_details = self.market_bets.read((market_id, caller));
            
            assert!(bet_details.predicted_outcome == winning_outcome, "No winning bet");
            
            let reward = (bet_details.stake * bet_details.odds) / BASE_REWARD_MULTIPLIER;
            self.rewards_claimed.write((market_id, caller), true);
            
            self.emit(Event::RewardClaimed(RewardClaimed {
                market_id,
                user: caller,
                amount: reward
            }));
        }

        fn register_ai_agent(ref self: ContractState, agent_address: ContractAddress, credentials: felt252) {
            let caller = get_caller_address();
            assert!(self.roles.read((caller, ADMIN_ROLE)), "Admin only");
            
            let agent_details = AIAgentDetails {
                is_verified: true,
                reputation: 100,
                credentials: credentials
            };
            
            self.ai_agents.write(agent_address, agent_details);
            
            self.emit(Event::AIAgentRegistered(AIAgentRegistered {
                agent: agent_address,
                credentials
            }));
        }

        fn update_ai_agent_reputation(
            ref self: ContractState,
            agent_address: ContractAddress,
            reputation_score: u256
        ) {
            let caller = get_caller_address();
            assert!(self.roles.read((caller, ADMIN_ROLE)), "Admin only");
            assert!(reputation_score <= MAX_REPUTATION_SCORE, "Invalid reputation score");
            
            let mut agent_details = self.ai_agents.read(agent_address);
            assert!(agent_details.is_verified, "Agent not verified");
            
            agent_details.reputation = reputation_score;
            self.ai_agents.write(agent_address, agent_details);
        }

        fn submit_ai_analysis(
            ref self: ContractState,
            market_id: u32,
            confidence_score: u256,
            analysis_data: Array<felt252>
        ) {
            let caller = get_caller_address();
            let agent_details = self.ai_agents.read(caller);
            
            assert!(agent_details.is_verified, "Agent not verified");
            assert!(confidence_score >= MIN_CONFIDENCE_SCORE, "Low confidence score");
            assert!(agent_details.reputation >= MIN_CONFIDENCE_SCORE, "Low reputation score");
            
            let analysis = AIAnalysis {
                confidence_score,
                analysis_data
            };
            
            self.ai_analyses.write(market_id, analysis);
            
            self.emit(Event::AIAnalysisSubmitted(AIAnalysisSubmitted {
                market_id,
                agent: caller,
                confidence_score
            }));
        }

        fn update_supply_metrics(ref self: ContractState, market_id: u32, metrics: Array<u256>) {
            let caller = get_caller_address();
            assert!(self.roles.read((caller, ORACLE_ROLE)), "Oracle only");
            
            let market_details = self.market_details.read(market_id);
            assert!(market_details.market_type == 1, "Not supply chain market");
            assert!(!market_details.is_closed, "Market closed");
            
            self.supply_metrics.write(market_id, metrics);
            
            self.emit(Event::SupplyMetricsUpdated(SupplyMetricsUpdated {
                market_id,
                timestamp: get_block_timestamp()
            }));
        }

        fn update_robot_forecast(
            ref self: ContractState,
            market_id: u32,
            robot_id: felt252,
            efficiency_score: u256,
            forecast_data: Array<felt252>
        ) {
            let caller = get_caller_address();
            assert!(self.roles.read((caller, ORACLE_ROLE)), "Oracle only");
            
            let market_details = self.market_details.read(market_id);
            assert!(market_details.market_type == 2, "Not robotics market");
            assert!(!market_details.is_closed, "Market closed");
            
            let forecast = RobotForecast {
                efficiency_score,
                forecast_data
            };
            
            self.robot_forecasts.write((market_id, robot_id), forecast);
            
            self.emit(Event::RobotForecastUpdated(RobotForecastUpdated {
                market_id,
                robot_id,
                efficiency_score
            }));
        }

        fn get_market_details(self: @ContractState, market_id: u32) -> MarketDetails {
            self.market_details.read(market_id)
        }

        fn get_ai_analysis(self: @ContractState, market_id: u32) -> AIAnalysis {
            self.ai_analyses.read(market_id)
        }

        fn get_supply_metrics(self: @ContractState, market_id: u32) -> Array<u256> {
            self.supply_metrics.read(market_id)
        }

        fn get_robot_efficiency_forecast(
            self: @ContractState,
            market_id: u32,
            robot_id: felt252
        ) -> RobotForecast {
            self.robot_forecasts.read((market_id, robot_id))
        }

        fn get_ai_agent_details(self: @ContractState, agent_address: ContractAddress) -> AIAgentDetails {
            self.ai_agents.read(agent_address)
        }

        fn get_total_liquidity(self: @ContractState) -> u256 {
            self.total_liquidity_pool.read()
        }

        fn get_market_stats(self: @ContractState, market_id: u32) -> BetDetails {
            self.market_bets.read((market_id, get_caller_address()))
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn calculate_odds(self: @ContractState, market_id: u32, stake: u256) -> u256 {
            let total_market_stake = self.market_total_stakes.read(market_id);
            let total_liquidity = self.total_liquidity_pool.read();
            
            // Base odds calculation
            let base_odds = if total_market_stake.is_zero() {
                BASE_REWARD_MULTIPLIER
            } else {
                (total_liquidity * BASE_REWARD_MULTIPLIER) / total_market_stake
            };
            
            // Apply AI analysis modifier
            let analysis = self.ai_analyses.read(market_id);
            let adjusted_odds = if analysis.confidence_score > 0 {
                (base_odds * analysis.confidence_score) / MAX_REPUTATION_SCORE
            } else {
                base_odds
            };
            
            // Apply risk adjustment
            let risk_score = self.market_risk_scores.read(market_id);
            let final_odds = if risk_score > 0 {
                (adjusted_odds * (MAX_REPUTATION_SCORE - risk_score)) / MAX_REPUTATION_SCORE
            } else {
                adjusted_odds
            };
            
            // Ensure minimum odds
            if final_odds < BASE_REWARD_MULTIPLIER {
                BASE_REWARD_MULTIPLIER
            } else {
                final_odds
            }
        }

        fn check_risk_thresholds(ref self: ContractState, market_id: u32) -> bool {
            let total_stake = self.market_total_stakes.read(market_id);
            let total_liquidity = self.total_liquidity_pool.read();
            
            // Calculate risk score based on stake to liquidity ratio
            let risk_score = if total_liquidity.is_zero() {
                MAX_REPUTATION_SCORE
            } else {
                (total_stake * MAX_REPUTATION_SCORE) / total_liquidity
            };
            
            self.market_risk_scores.write(market_id, risk_score);
            
            // Trigger circuit breaker if risk is too high
            if risk_score > MAX_REPUTATION_SCORE * 3 / 4 {
                self.circuit_breaker_triggered.write(true);
                self.emit(Event::CircuitBreakerTriggered(CircuitBreakerTriggered {
                    timestamp: get_block_timestamp(),
                    reason: 'high_risk_score'
                }));
                false
            } else {
                true
            }
        }
    }
}