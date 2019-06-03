use crate::{
    credentials::Credentials,
    error::ServiceError,
    global,
    session,
};
use actix_web::{
    web,
    Error,
    HttpRequest,
    HttpResponse,
};
use diwata_intel::{
    data_read,
    error::IntelError,
    window,
    Dao,
    TableName,
};
use futures::future::Future;
use serde::{
    Deserialize,
    Serialize,
};
use std::convert::TryFrom;

fn require_credentials(req: &HttpRequest) -> Result<(), ServiceError> {
    let is_required = global::is_login_required().unwrap();

    if is_required {
        let credentials: Result<Credentials, ServiceError> =
            TryFrom::try_from(req);
        match credentials {
            Ok(credentials) => {
                global::test_credentials(
                    &credentials.username,
                    &credentials.password,
                )?;
                Ok(())
            }
            Err(_e) => Err(ServiceError::RequiredCredentialsNotFound),
        }
    } else {
        Ok(())
    }
}

// FIXME: learn how to do custom error in actix
pub fn windows(
    req: HttpRequest,
) -> impl Future<Item = HttpResponse, Error = Error> {
    require_credentials(&req).expect("Should have credentials");
    let credentials: Result<Credentials, ServiceError> =
        TryFrom::try_from(&req);
    let context =
        session::create_context(credentials).expect("unable to create context");
    let is_login_required = global::is_login_required().unwrap();
    let db_url = if is_login_required {
        global::get_role_db_url().unwrap()
    } else {
        global::get_db_url().unwrap()
    };

    web::block(move || {
        window::get_grouped_windows_using_cache(&context.em, &db_url)
            .map_err(|err| ServiceError::IntelError(err))
    })
    .from_err()
    .then(move |rows| {
        match rows {
            Ok(rows) => {
                Ok(HttpResponse::Ok().body(
                    ron::ser::to_string(&rows)
                        .expect("unable to serialize to ron"),
                ))
            }
            Err(e) => Err(e),
        }
    })
}

#[derive(Deserialize)]
pub struct SqlParam {
    sql: String,
}

// FIXME: learn how to do custom error in actix
pub fn sql(
    req: HttpRequest,
    sql_param: web::Query<SqlParam>,
) -> impl Future<Item = HttpResponse, Error = Error> {
    require_credentials(&req).expect("Should have credentials");
    let credentials: Result<Credentials, ServiceError> =
        TryFrom::try_from(&req);
    let context =
        session::create_context(credentials).expect("unable to create context");

    web::block(move || data_read::execute_sql_query(&context, &sql_param.sql))
        .from_err()
        .then(move |rows| {
            match rows {
                Ok(rows) => {
                    Ok(HttpResponse::Ok().body(
                        ron::ser::to_string(&rows)
                            .expect("unable to serialize to ron"),
                    ))
                }
                Err(e) => Err(e),
            }
        })
}

#[derive(Debug, Deserialize)]
pub struct DaoParam {
    dao: String,
}

pub fn record_detail(
    req: HttpRequest,
    table_name_param: web::Path<(String)>,
    dao_param: web::Query<DaoParam>,
) -> impl Future<Item = HttpResponse, Error = Error> {
    require_credentials(&req).expect("Should have credentials");
    let credentials: Result<Credentials, ServiceError> =
        TryFrom::try_from(&req);
    let context =
        session::create_context(credentials).expect("unable to create context");
    let table_name = TableName::from(&table_name_param.to_string());
    let dao: Dao =
        ron::de::from_str(&dao_param.dao).expect("Unable to deserialize dao");

    web::block(move || {
        let detail = data_read::fetch_detail(&context, &table_name, &dao);
        println!("detail: {:#?}", detail);
        detail
    })
    .from_err()
    .then(move |record_detail| {
        match record_detail {
            Ok(record_detail) => {
                Ok(HttpResponse::Ok().body(
                    ron::ser::to_string(&record_detail)
                        .expect("unable to serialize to ron"),
                ))
            }
            Err(e) => Err(e),
        }
    })
}