import TradesPage from "../components/tradesPage";
import TradeStore from "../components/myMoney/stores/tradeStore";

const TradesRoute = () => {
  return <TradeStore.Provider>
    <TradesPage />
  </TradeStore.Provider>;
};

TradesRoute.getInitialProps = () => {
  return {
    title: "Trades - Vedora",
  };
};

export default TradesRoute;
