use crate::app::field_view::{self, FieldView};
use data_table::DataRow;
use sauron::{
    html::{attributes::*, events::*, *},
    Component, Node,
};
use std::{cell::RefCell, rc::Rc};

#[derive(Clone)]
pub enum Msg {
    FieldMsg(usize, field_view::Msg),
    DoubleClick,
    Click,
}

pub struct RowView {
    pub fields: Vec<Rc<RefCell<FieldView>>>,
    frozen_fields: Vec<usize>,
}

impl RowView {
    pub fn new(data_rows: DataRow) -> Self {
        RowView {
            fields: data_rows
                .into_iter()
                .map(|value| Rc::new(RefCell::new(FieldView::new(value))))
                .collect(),
            frozen_fields: vec![],
        }
    }

    pub fn freeze_columns(&mut self, columns: Vec<usize>) {
        sauron::log!("row view freeze columns: {:?}", columns);
        self.frozen_fields = columns;
    }

    fn view_with_filter<F>(&self, filter: F) -> Node<Msg>
    where
        F: Fn(&(usize, &Rc<RefCell<FieldView>>)) -> bool,
    {
        li(
            [
                class("row"),
                styles([("height", px(Self::row_height()))]),
                onclick(|_| Msg::Click),
                ondblclick(|_| Msg::DoubleClick),
            ],
            self.fields
                .iter()
                .enumerate()
                .filter(filter)
                .map(|(index, field)| {
                    field
                        .borrow()
                        .view()
                        .map(move |field_msg| Msg::FieldMsg(index, field_msg))
                })
                .collect::<Vec<Node<Msg>>>(),
        )
    }

    pub fn view_frozen(&self) -> Node<Msg> {
        self.view_with_filter(|(index, _field)| self.frozen_fields.contains(index))
    }

    pub fn row_height() -> i32 {
        30
    }
}

impl Component<Msg> for RowView {
    fn update(&mut self, _msg: Msg) {}

    fn view(&self) -> Node<Msg> {
        self.view_with_filter(|(index, _field)| !self.frozen_fields.contains(index))
    }
}
