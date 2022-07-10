#![feature(read_buf)]
use std::{
    collections::BTreeMap,
    fs::File,
    io::{BufRead, BufReader, Read, ReadBuf},
    marker::PhantomData,
    sync::Arc,
};

use chrono::NaiveDateTime;

use arrow2::{
    array::{Array, BooleanArray, Int64Array, StructArray, UInt64Array, Utf8Array},
    chunk::Chunk,
    datatypes::{DataType, Field, Schema},
    error::Result,
    io::{
        csv::read::{deserialize_column, ByteRecord, ReaderBuilder},
        parquet::{
            read::FileReader,
            write::{
                transverse, CompressionOptions, Encoding, FileWriter, RowGroupIterator, Version,
                WriteOptions,
            },
        },
    },
};
use nautilus_core::time::Timestamp;
use nautilus_model::{
    data::tick::QuoteTick,
    identifiers::instrument_id::InstrumentId,
    types::{price::Price, quantity::Quantity},
};

fn write_batch(path: &str, schema: Schema, columns: Chunk<Box<dyn Array>>) -> Result<()> {
    let options = WriteOptions {
        write_statistics: true,
        compression: CompressionOptions::Uncompressed,
        version: Version::V2,
    };

    let iter = vec![Ok(columns)];

    let encodings = schema
        .fields
        .iter()
        .map(|f| transverse(&f.data_type, |_| Encoding::Plain))
        .collect();

    let row_groups = RowGroupIterator::try_new(iter.into_iter(), &schema, options, encodings)?;

    // Create a new empty file
    let file = File::create(path)?;

    let mut writer = FileWriter::try_new(file, schema, options)?;

    for group in row_groups {
        writer.write(group?)?;
    }
    let _size = writer.end(None)?;
    Ok(())
}

#[derive(Debug)]
struct InnerValue {
    c: String,
}

#[derive(Debug)]
struct Value {
    a: u64,
    b: bool,
    d: InnerValue,
}

fn write_struct_array() {
    //////////////////////////////////////
    // Write parquet
    //////////////////////////////////////

    let values = vec![
        Value {
            a: 1,
            b: true,
            d: InnerValue {
                c: "hi".to_string(),
            },
        },
        Value {
            a: 2,
            b: false,
            d: InnerValue {
                c: "hola".to_string(),
            },
        },
        Value {
            a: 3,
            b: false,
            d: InnerValue {
                c: "bola".to_string(),
            },
        },
        Value {
            a: 4,
            b: true,
            d: InnerValue {
                c: "chola".to_string(),
            },
        },
    ];

    let a_array = UInt64Array::from_slice(values.iter().map(|v| v.a).collect::<Vec<u64>>()).arced();
    let b_array =
        BooleanArray::from_slice(values.iter().map(|v| v.b).collect::<Vec<bool>>()).arced();
    let d_array = Utf8Array::<i32>::from_slice(
        values
            .iter()
            .map(|v| v.d.c.clone())
            .collect::<Vec<String>>(),
    )
    .arced();

    let fields = vec![
        Field::new("a", DataType::UInt64, false),
        Field::new("b", DataType::Boolean, false),
        Field::new("d", DataType::Utf8, false),
    ];

    let array = StructArray::new(
        DataType::Struct(fields.clone()),
        vec![a_array, b_array, d_array],
        None,
    );
    let schema = Schema::from(vec![Field::new("bid", DataType::Struct(fields), false)]);
    let columns = Chunk::new(vec![array.boxed()]);
    write_batch("struct.parquet", schema, columns).unwrap();

    //////////////////////////////////////
    // Read parquet
    //////////////////////////////////////

    let f = File::open("struct.parquet").unwrap();
    let fr = FileReader::try_new(&f, None, None, None, None).unwrap();

    for chunk in fr.into_iter() {
        if let Ok(cols) = chunk {
            for array in cols.arrays().iter() {
                match array.data_type().to_physical_type() {
                    // convert array to struct array
                    arrow2::datatypes::PhysicalType::Struct => {
                        let struct_array = array.as_any().downcast_ref::<StructArray>().unwrap();
                        dbg!(struct_array);

                        // deconstruct individual field arrays from struct array
                        let values = struct_array.values();
                        let a_values = values[0].as_any().downcast_ref::<UInt64Array>().unwrap();
                        let b_values = values[1].as_any().downcast_ref::<BooleanArray>().unwrap();
                        let d_values = values[2].as_any().downcast_ref::<Utf8Array<i32>>().unwrap();

                        // construct iterator of values from field value arrays
                        let values = a_values
                            .into_iter()
                            .zip(b_values.into_iter())
                            .zip(d_values.into_iter())
                            .map(|((a, b), d)| Value {
                                a: *a.unwrap(),
                                b: b.unwrap(),
                                d: InnerValue {
                                    c: d.unwrap().to_string(),
                                },
                            });

                        // collect vector of values if needed
                        let vec_values: Vec<Value> = values.collect();
                        dbg!(vec_values);
                    }
                    _ => todo!(),
                }
            }
        }
    }
}

fn write_array_of_arrays() {
    let values = vec![
        Value {
            a: 1,
            b: true,
            d: InnerValue {
                c: "hi".to_string(),
            },
        },
        Value {
            a: 2,
            b: false,
            d: InnerValue {
                c: "hola".to_string(),
            },
        },
        Value {
            a: 3,
            b: false,
            d: InnerValue {
                c: "bola".to_string(),
            },
        },
        Value {
            a: 4,
            b: true,
            d: InnerValue {
                c: "chola".to_string(),
            },
        },
    ];

    let a_array = UInt64Array::from_slice(values.iter().map(|v| v.a).collect::<Vec<u64>>()).arced();
    let b_array =
        BooleanArray::from_slice(values.iter().map(|v| v.b).collect::<Vec<bool>>()).arced();
    let d_array = Utf8Array::<i32>::from_slice(
        values
            .iter()
            .map(|v| v.d.c.clone())
            .collect::<Vec<String>>(),
    )
    .arced();

    let fields = vec![
        Field::new("a", DataType::UInt64, false),
        Field::new("b", DataType::Boolean, false),
        Field::new("d", DataType::Utf8, false),
    ];

    let schema = Schema::from(fields);
    let columns = Chunk::new(vec![
        a_array.to_boxed(),
        b_array.to_boxed(),
        d_array.to_boxed(),
    ]);
    write_batch("array_of_arrays.parquet", schema, columns).unwrap();

    let f = File::open("array_of_arrays.parquet").unwrap();
    let fr = FileReader::try_new(&f, None, None, None, None).unwrap();

    for chunk in fr.into_iter() {
        if let Ok(cols) = chunk {
            // extract field value arrays from chunk separately
            let a_values = cols.arrays()[0]
                .as_any()
                .downcast_ref::<UInt64Array>()
                .unwrap();
            let b_values = cols.arrays()[1]
                .as_any()
                .downcast_ref::<BooleanArray>()
                .unwrap();
            let d_values = cols.arrays()[2]
                .as_any()
                .downcast_ref::<Utf8Array<i32>>()
                .unwrap();

            // construct iterator of values from field value arrays
            let values = a_values
                .into_iter()
                .zip(b_values.into_iter())
                .zip(d_values.into_iter())
                .map(|((a, b), d)| Value {
                    a: *a.unwrap(),
                    b: b.unwrap(),
                    d: InnerValue {
                        c: d.unwrap().to_string(),
                    },
                });

            // collect vector of values if needed
            let vec_values: Vec<Value> = values.collect();
            dbg!(vec_values);
        }
    }
}

fn write_quote_tick_to_parquet(data: Vec<QuoteTick>) {
    let instrument_id = InstrumentId::from("EUR/USD.SIM");
    let precision: u8 = 10;
    let fields = vec![
        Field::new("bid", DataType::Int64, false),
        Field::new("ask", DataType::Int64, false),
        Field::new("bid_size", DataType::UInt64, false),
        Field::new("ask_size", DataType::UInt64, false),
        Field::new("ts", DataType::UInt64, false),
    ];

    dbg!(data[0].ask.precision);
    dbg!(data[0].ask_size.precision);

    let mut metadata = BTreeMap::new();
    metadata.insert("instrument_id".to_string(), instrument_id.to_string());
    metadata.insert(
        "price_precision".to_string(),
        data[0].ask.precision.to_string(),
    );
    metadata.insert(
        "qty_precision".to_string(),
        data[0].ask_size.precision.to_string(),
    );
    let schema = Schema::from(fields).with_metadata(metadata);

    let (mut bid_field, mut ask_field, mut bid_size, mut ask_size, mut ts): (
        Vec<i64>,
        Vec<i64>,
        Vec<u64>,
        Vec<u64>,
        Vec<u64>,
    ) = (vec![], vec![], vec![], vec![], vec![]);

    data.iter().fold((), |(), quote| {
        bid_field.push(quote.bid.raw);
        ask_field.push(quote.ask.raw);
        ask_size.push(quote.ask_size.raw);
        bid_size.push(quote.bid_size.raw);
        ts.push(quote.ts_init);
    });

    let ask_array = Int64Array::from_vec(ask_field);
    let bid_array = Int64Array::from_vec(bid_field);
    let ask_size_array = UInt64Array::from_vec(ask_size);
    let bid_size_array = UInt64Array::from_vec(bid_size);
    let ts_array = UInt64Array::from_vec(ts);
    let columns = Chunk::new(vec![
        bid_array.to_boxed(),
        ask_array.to_boxed(),
        ask_size_array.to_boxed(),
        bid_size_array.to_boxed(),
        ts_array.to_boxed(),
    ]);

    write_batch("quote_data.parquet", schema, columns).unwrap();

    //////////////////////////////////////
    // Read parquet
    //////////////////////////////////////

    let f = File::open("quote_data.parquet").unwrap();
    let fr = FileReader::try_new(&f, None, None, None, None).unwrap();
    let schema = fr.schema();
    let instrument_id = InstrumentId::from(schema.metadata.get("instrument_id").unwrap());
    let price_precision = schema
        .metadata
        .get("price_precision")
        .unwrap()
        .parse::<u8>()
        .unwrap();
    let qty_precision = schema
        .metadata
        .get("qty_precision")
        .unwrap()
        .parse::<u8>()
        .unwrap();

    for chunk in fr.into_iter() {
        if let Ok(cols) = chunk {
            // extract field value arrays from chunk separately
            let bid_values = cols.arrays()[0]
                .as_any()
                .downcast_ref::<Int64Array>()
                .unwrap();
            let ask_values = cols.arrays()[1]
                .as_any()
                .downcast_ref::<Int64Array>()
                .unwrap();
            let ask_size_values = cols.arrays()[2]
                .as_any()
                .downcast_ref::<UInt64Array>()
                .unwrap();
            let bid_size_values = cols.arrays()[3]
                .as_any()
                .downcast_ref::<UInt64Array>()
                .unwrap();
            let ts_values = cols.arrays()[4]
                .as_any()
                .downcast_ref::<UInt64Array>()
                .unwrap();

            // construct iterator of values from field value arrays
            let values = bid_values
                .into_iter()
                .zip(ask_values.into_iter())
                .zip(ask_size_values.into_iter())
                .zip(bid_size_values.into_iter())
                .zip(ts_values.into_iter())
                .map(|((((bid, ask), ask_size), bid_size), ts)| QuoteTick {
                    instrument_id: instrument_id.clone(),
                    bid: Price::from_raw(*bid.unwrap(), price_precision),
                    ask: Price::from_raw(*ask.unwrap(), price_precision),
                    bid_size: Quantity::from_raw(*bid_size.unwrap(), qty_precision),
                    ask_size: Quantity::from_raw(*ask_size.unwrap(), qty_precision),
                    ts_event: *ts.unwrap(),
                    ts_init: *ts.unwrap(),
                });

            // collect vector of values if needed
            let vec_values: Vec<QuoteTick> = values.collect();

            assert_eq!(vec_values, data);
        }
    }
}

trait DecodeFromChunk
where
    Self: Sized,
{
    fn decode(schema: &Schema, chunk: Chunk<Arc<dyn Array>>) -> Vec<Self>;
}

struct ParquetReader<'a, A> {
    file_reader: FileReader<&'a File>,
    reader_type: PhantomData<*const A>,
}

impl<'a, A> ParquetReader<'a, A> {
    fn new(f: &'a File, chunk_size: usize) -> Self {
        let fr = FileReader::try_new(f, None, Some(chunk_size), None, None)
            .expect("Unable to create reader from file")
            .into_iter();
        ParquetReader {
            file_reader: fr,
            reader_type: PhantomData,
        }
    }
}

impl<'a, A> Iterator for ParquetReader<'a, A>
where
    A: DecodeFromChunk,
{
    type Item = Vec<A>;

    fn next(&mut self) -> Option<Self::Item> {
        if let Some(Ok(chunk)) = self.file_reader.next() {
            Some(A::decode(self.file_reader.schema(), chunk))
        } else {
            None
        }
    }
}

fn load_data_from_csv() -> Vec<QuoteTick> {
    let f = File::open("./common/quote_tick_data.csv").unwrap();
    let mut rdr = BufReader::with_capacity(39 * 10, f);

    let instrument = InstrumentId::from("EUR/USD.SIM");
    let bid_size = Quantity::from_raw(100_000, 0);
    let ask_size = Quantity::from_raw(100_000, 0);

    loop {
        let mut bytes_read = 0;
        if let Ok(data) = rdr.fill_buf() {
            bytes_read = data.len();
            let mut csv_rdr = ReaderBuilder::new().from_reader(data);
            let records: Vec<ByteRecord> = csv_rdr
                .into_byte_records()
                .filter_map(|rec| rec.ok())
                .collect();
            let ts: Vec<Timestamp> = deserialize_column(&records, 0, DataType::Utf8, 0)
                .unwrap()
                .as_any()
                .downcast_ref::<Utf8Array<i32>>()
                .unwrap()
                .into_iter()
                .map(|ts_val| {
                    ts_val.map(|ts_val| {
                        NaiveDateTime::parse_from_str(ts_val, "%Y%m%d %H%M%S%f")
                            .unwrap()
                            .timestamp_nanos() as Timestamp
                    })
                })
                .collect::<Option<Vec<_>>>()
                .unwrap();
            let bid: Vec<Price> = deserialize_column(&records, 1, DataType::Utf8, 0)
                .unwrap()
                .as_any()
                .downcast_ref::<Utf8Array<i32>>()
                .unwrap()
                .into_iter()
                .map(|bid_val| bid_val.map(|bid_val| Price::from(bid_val)))
                .collect::<Option<Vec<_>>>()
                .unwrap();
            let ask: Vec<Price> = deserialize_column(&records, 2, DataType::Utf8, 0)
                .unwrap()
                .as_any()
                .downcast_ref::<Utf8Array<i32>>()
                .unwrap()
                .into_iter()
                .map(|ask_val| ask_val.map(|ask_val| Price::from(ask_val)))
                .collect::<Option<Vec<_>>>()
                .unwrap();

            // construct iterator of values from field value arrays
            let values = ts
                .into_iter()
                .zip(bid.into_iter())
                .zip(ask.into_iter())
                .map(|((ts, bid), ask)| QuoteTick {
                    instrument_id: instrument.clone(),
                    bid,
                    ask,
                    bid_size: bid_size.clone(),
                    ask_size: ask_size.clone(),
                    ts_event: ts,
                    ts_init: ts,
                });

            let value_vec: Vec<QuoteTick> = values.collect();
            // println!("{}", value_vec.len())
            return value_vec;
        } else {
            println!("done reading");
            break vec![];
        }

        if (bytes_read == 0) {
            break vec![];
        } else {
            rdr.consume(bytes_read);
        }
    }
}

fn main() {
    // write_struct_array();
    // write_array_of_arrays();
    let quote_data = load_data_from_csv();
    write_quote_tick_to_parquet(quote_data);
}
