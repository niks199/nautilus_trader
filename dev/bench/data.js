window.BENCHMARK_DATA = {
  "lastUpdate": 1632558241660,
  "repoUrl": "https://github.com/nautechsystems/nautilus_trader",
  "entries": {
    "Benchmark with pytest-benchmark": [
      {
        "commit": {
          "author": {
            "name": "nautechsystems",
            "username": "nautechsystems"
          },
          "committer": {
            "name": "nautechsystems",
            "username": "nautechsystems"
          },
          "id": "94fda59aec89cbc1765b6690c32975dd5b21ee45",
          "message": "Fix paths on windows",
          "timestamp": "2021-09-15T09:49:14Z",
          "url": "https://github.com/nautechsystems/nautilus_trader/pull/444/commits/94fda59aec89cbc1765b6690c32975dd5b21ee45"
        },
        "date": 1632558234524,
        "tool": "pytest",
        "benches": [
          {
            "name": "tests/performance_tests/test_perf_xrate_calculator.py::TestExchangeRateCalculatorPerformanceTests::test_get_xrate",
            "value": 95899.28932824694,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 10.427605950000007 usec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_stats.py::TestFunctionPerformance::test_np_mean",
            "value": 69364.03178212703,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 14.416693700000138 usec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_stats.py::TestFunctionPerformance::test_np_std",
            "value": 22693.11844935052,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 44.06622220000003 usec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_stats.py::TestFunctionPerformance::test_fast_mean",
            "value": 2316770.018549341,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 431.63542000002053 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_stats.py::TestFunctionPerformance::test_fast_std",
            "value": 1406527.1891481203,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 710.9709699999911 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_serialization.py::TestSerializationPerformance::test_serialize_submit_order",
            "value": 119628.37922506935,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 8.35922050000022 usec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_queues.py::TestPythonDequePerformance::test_append",
            "value": 17989477.9543454,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 55.588049999997224 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_queues.py::TestPythonDequePerformance::test_peek",
            "value": 6181350.309793954,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 161.7769499999966 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_orderbook.py::test_orderbook_updates",
            "value": 3.787663225795306,
            "unit": "iter/sec",
            "range": "stddev: 0.001210938353721172",
            "extra": "mean: 264.0150246700002 msec\nrounds: 10"
          },
          {
            "name": "tests/performance_tests/test_perf_order.py::TestOrderPerformance::test_order_id_generator",
            "value": 237567.36905756456,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 4.209332299999886 usec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_order.py::TestOrderPerformance::test_market_order_creation",
            "value": 25690.93337519341,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 38.92423780000058 usec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_order.py::TestOrderPerformance::test_limit_order_creation",
            "value": 23491.792947152146,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 42.56805779999979 usec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_objects.py::TestObjectPerformance::test_make_symbol",
            "value": 2931737.9128330494,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 341.09460999999897 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_objects.py::TestObjectPerformance::test_make_instrument_id",
            "value": 2166325.300736789,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 461.6111899998998 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_objects.py::TestObjectPerformance::test_instrument_id_to_str",
            "value": 10944411.909141337,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 91.37082999998825 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_objects.py::TestObjectPerformance::test_build_bar_no_checking",
            "value": 3143776.6975415833,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 318.0887499999585 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_objects.py::TestObjectPerformance::test_build_bar_with_checking",
            "value": 3015479.754234353,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 331.6221900000471 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_live_execution.py::TestLiveExecutionPerformance::test_execute_command",
            "value": 40496.95383330609,
            "unit": "iter/sec",
            "range": "stddev: 0.00011991352739078281",
            "extra": "mean: 24.693215300000304 usec\nrounds: 100"
          },
          {
            "name": "tests/performance_tests/test_perf_live_execution.py::TestLiveExecutionPerformance::test_submit_order",
            "value": 8257.823451615846,
            "unit": "iter/sec",
            "range": "stddev: 0.00011677746523707065",
            "extra": "mean: 121.09728499999903 usec\nrounds: 100"
          },
          {
            "name": "tests/performance_tests/test_perf_live_execution.py::TestLiveExecutionPerformance::test_submit_order_end_to_end",
            "value": 2.9306231569644687,
            "unit": "iter/sec",
            "range": "stddev: 0.26518722641609016",
            "extra": "mean: 341.2243561999958 msec\nrounds: 10"
          },
          {
            "name": "tests/performance_tests/test_perf_fill_model.py::TestFillModelPerformance::test_is_limit_filled",
            "value": 6590917.254655591,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 151.72395000007555 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_fill_model.py::TestFillModelPerformance::test_is_stop_filled",
            "value": 6567446.559702312,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 152.26617999999803 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_experiments.py::TestPerformanceExperiments::test_builtin_arithmetic",
            "value": 9078118.022607187,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 110.15499000009754 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_experiments.py::TestPerformanceExperiments::test_class_name",
            "value": 5167734.0535250055,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 193.50840999990737 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_experiments.py::TestPerformanceExperiments::test_is_instance",
            "value": 13570257.361304214,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 73.6905699999113 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_experiments.py::TestPerformanceExperiments::test_is_message_type",
            "value": 15787482.799557155,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 63.3413199999211 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_make_builtin_decimal",
            "value": 2780882.091968559,
            "unit": "iter/sec",
            "range": "stddev: 1.617604359597297e-7",
            "extra": "mean: 359.5981299919515 nsec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_make_decimal",
            "value": 742578.3802144347,
            "unit": "iter/sec",
            "range": "stddev: 5.673440161763317e-7",
            "extra": "mean: 1.3466591899850755 usec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_make_price",
            "value": 520734.2256800557,
            "unit": "iter/sec",
            "range": "stddev: 9.329760250186097e-7",
            "extra": "mean: 1.9203654199876043 usec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_make_price_from_float",
            "value": 531390.2446783265,
            "unit": "iter/sec",
            "range": "stddev: 7.287501934601914e-7",
            "extra": "mean: 1.8818561500039266 usec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_float_comparisons",
            "value": 3934887.991766731,
            "unit": "iter/sec",
            "range": "stddev: 2.0683708149190225e-7",
            "extra": "mean: 254.1368400046906 nsec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_decimal_comparisons",
            "value": 1477137.2973212386,
            "unit": "iter/sec",
            "range": "stddev: 4.900730865517722e-7",
            "extra": "mean: 676.9851399822358 nsec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_builtin_decimal_comparisons",
            "value": 2610303.190580494,
            "unit": "iter/sec",
            "range": "stddev: 1.5937299458788386e-7",
            "extra": "mean: 383.09725996910515 nsec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_float_arithmetic",
            "value": 5503850.2458109455,
            "unit": "iter/sec",
            "range": "stddev: 1.8921735105993446e-7",
            "extra": "mean: 181.69099000488131 nsec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_builtin_decimal_arithmetic",
            "value": 1192840.343249746,
            "unit": "iter/sec",
            "range": "stddev: 4.3090298955916294e-7",
            "extra": "mean: 838.3351599893274 nsec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_decimal_arithmetic",
            "value": 677981.4815205294,
            "unit": "iter/sec",
            "range": "stddev: 7.016907254259376e-7",
            "extra": "mean: 1.474966540025946 usec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_decimal.py::TestDecimalPerformance::test_decimal_arithmetic_with_floats",
            "value": 797548.0183697378,
            "unit": "iter/sec",
            "range": "stddev: 7.153800767580247e-7",
            "extra": "mean: 1.2538430000040535 usec\nrounds: 100000"
          },
          {
            "name": "tests/performance_tests/test_perf_correctness.py::TestCorrectnessConditionPerformance::test_condition_none",
            "value": 17645588.011881452,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 56.671389999962685 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_correctness.py::TestCorrectnessConditionPerformance::test_condition_true",
            "value": 16874156.924936432,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 59.262219999993704 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_correctness.py::TestCorrectnessConditionPerformance::test_condition_valid_string",
            "value": 8199013.002813335,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 121.96590000002062 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_correctness.py::TestCorrectnessConditionPerformance::test_condition_type_or_none",
            "value": 15092141.29565027,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 66.25964999997791 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_clock.py::TestLiveClockPerformance::test_utc_now",
            "value": 9574800.351057585,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 104.4408199999225 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_clock.py::TestLiveClockPerformance::test_unix_timestamp",
            "value": 10402080.998715509,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 96.13461000000711 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_clock.py::TestLiveClockPerformance::test_unix_timestamp_ns",
            "value": 9441911.284559418,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 105.91075999997202 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_clock.py::TestClockPerformanceTests::test_advance_time",
            "value": 11934676.740343992,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 83.78944999989812 nsec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_clock.py::TestClockPerformanceTests::test_iteratively_advance_time",
            "value": 177.60090306518094,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 5.630601999996543 msec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_backtest.py::TestBacktestEnginePerformance::test_run_with_empty_strategy",
            "value": 2.3151404779087574,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 431.9392319999906 msec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_backtest.py::TestBacktestEnginePerformance::test_run_for_tick_processing",
            "value": 7.565327339193601,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 132.18198699999562 msec\nrounds: 1"
          },
          {
            "name": "tests/performance_tests/test_perf_backtest.py::TestBacktestEnginePerformance::test_run_with_ema_cross_strategy",
            "value": 1.3180287525072696,
            "unit": "iter/sec",
            "range": "stddev: 0",
            "extra": "mean: 758.70879 msec\nrounds: 1"
          }
        ]
      }
    ]
  }
}