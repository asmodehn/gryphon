"""
This is a simple market making strategy to demonstrate use of the Gryphon
framework. It follows the same tick-logic as SuperSimpleMarketMaking, but it's target
exchange, spread, and base volume, are all configurable.
"""

from cdecimal import Decimal

from gryphon.execution.strategies.base import Strategy
from gryphon.lib import market_making as mm
from gryphon.lib.money import Money
from gryphon.lib.exchange.consts import Consts


class SimpleMarketMaking(Strategy):
    def __init__(self, db, harness, strategy_configuration):
        super(SimpleMarketMaking, self).__init__(db, harness)

        # Configurable properties with defaults.
        self.spread = Decimal('0.01')
        self.base_volume = Money('0.005', 'BTC')
        self.exchange = None

        self.configure(strategy_configuration)

    def configure(self, strategy_configuration):
        super(SimpleMarketMaking, self).configure(strategy_configuration)

        self.init_configurable('spread', strategy_configuration)
        self.init_configurable('base_volume', strategy_configuration)
        self.init_configurable('exchange', strategy_configuration)
        self.init_primary_exchange()

    def init_primary_exchange(self):
        self.primary_exchange = self.harness.exchange_from_key(self.exchange)

        # This causes us to always audit our primary exchange.
        self.target_exchanges = [self.primary_exchange.name]

    def tick(self, current_orders):
        self.primary_exchange.cancel_all_open_orders()

        ob = self.primary_exchange.get_orderbook()

        bid_price, ask_price = mm.midpoint_centered_fixed_spread(ob, self.spread)

        bid_volume, ask_volume = mm.simple_position_responsive_sizing(
            self.base_volume,
            self.position,
        )
        print("balance: " + str(self.primary_exchange.get_balance()))
        print("bid volume: " + str(bid_volume) + " price: " + str(bid_price))
        print("ask volume: " + str(ask_volume) + " price: " + str(ask_price))

        # Place order only if we can...
        if self.primary_exchange.get_balance().get(bid_price.currency).amount > bid_price.amount * bid_volume.amount:
            self.primary_exchange.limit_order(Consts.BID, bid_volume, bid_price)

        # Place order only if we can...
        if self.primary_exchange.get_balance().get(ask_volume.currency).amount > ask_volume.amount:
            self.primary_exchange.limit_order(Consts.ASK, ask_volume, ask_price)

