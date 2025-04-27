import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type RadioFieldSet(a) {
  RadioFieldSet(
    name: String,
    legend: String,
    choices: List(#(String, Element(a))),
    checked: String,
    on_change: Option(fn(String) -> a),
  )
}

pub fn render_radio_fieldset(config: RadioFieldSet(a)) -> Element(a) {
  config.choices
  |> list.map(fn(choice) {
    let #(value, label) = choice
    let checked = config.checked == value
    render_radio_choice(
      name: config.name,
      value:,
      checked:,
      label:,
      on_change: config.on_change,
    )
  })
  |> render_fieldset(config.legend, _)
}

fn render_fieldset(
  legend legend: String,
  choices choices: List(Element(b)),
) -> Element(b) {
  html.fieldset([attribute.class("fieldset py-4")], [
    html.legend([attribute.class("fieldset-legend")], [html.text(legend)]),
    ..choices
  ])
}

fn render_radio_choice(
  name name: String,
  value value: String,
  checked checked: Bool,
  label label: Element(a),
  on_change message: Option(fn(String) -> a),
) -> Element(a) {
  let id = name <> "_" <> value
  html.div([attribute.class("flex flex-row items-center px-4")], [
    html.input([
      attribute.class("radio"),
      attribute.type_("radio"),
      attribute.name(name),
      attribute.value(value),
      attribute.id(id),
      attribute.checked(checked),
      case message {
        Some(message) -> event.on_change(message)
        None -> attribute.none()
      },
    ]),
    html.label([attribute.class("px-2"), attribute.for(id)], [label]),
  ])
}

pub fn render_input_field(
  prompt prompt: String,
  placeholder placeholder: String,
  is_disabled is_disabled: Bool,
  value value: String,
  on_input message: Option(fn(String) -> a),
) -> Element(a) {
  html.div([attribute.class("flex flex-row items-center")], [
    html.text(prompt),
    html.input([
      attribute.class("input"),
      attribute.type_("text"),
      attribute.placeholder(placeholder),
      attribute.value(value),
      attribute.disabled(is_disabled),
      case message {
        Some(message) -> event.on_input(message)
        None -> attribute.none()
      },
    ]),
  ])
}

pub fn render_dock(
  buttons buttons: List(#(String, Element(c))),
  active_page active_page: String,
  on_click message: fn(String) -> c,
) -> Element(c) {
  let render_dock_button = fn(button) {
    let #(button_page_name, button_icon) = button
    html.button(
      [
        case button_page_name == active_page {
          True -> attribute.class("dock-active")
          False -> attribute.none()
        },
        event.on_click(message(button_page_name)),
      ],
      [
        button_icon,
        html.span([attribute.class("dock-label")], [html.text(button_page_name)]),
      ],
    )
  }
  html.div(
    [attribute.class("dock shadow-sm bg-base-200")],
    list.map(buttons, render_dock_button),
  )
}
