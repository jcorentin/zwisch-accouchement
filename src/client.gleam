import accouchement.{type Accouchement} as acc
import answer.{type Answer}
import components
import fieldsets
import formal/form
import gleam/dict.{type Dict}
import gleam/dynamic/decode.{type Decoder}
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import icons
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import pocketbase_sdk as pb
import user.{type User}

const server = pb.PocketBase(host: "127.0.0.1", port: 8090)

// MAIN ------------------------------------------------------------------------

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// MODEL -----------------------------------------------------------------------

fn init(_args: Nil) -> #(Model, Effect(Msg)) {
  #(LoggedOut, read_auth_from_storage())
}

type Model {
  LoggedOut
  LoggedIn(token: String, user: User, page: Page)
}

type Page {
  PageAccueil
  PageAccouchement(
    user_questions: Dict(user.Question, Answer),
    acc_questions: Dict(acc.Question, Answer),
  )
  PageProfil
}

fn page_name(page: Page) {
  case page {
    PageProfil -> "Profil"
    PageAccueil -> "Accueil"
    PageAccouchement(..) -> "Accouchement"
  }
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  UserClickedDock(String)
  UserClickedLogout
  UserClickedSubmitAccouchement

  UserChangedAnswerAccouchement(#(acc.Question, Answer))
  UserChangedAnswerUser(#(user.Question, Answer))

  UserSubmittedLoginForm(Result(LoginData, form.Form))
  UserSubmittedUserUpdate(Result(User, form.Form))

  ApiReturnedAuth(Result(pb.Auth(User), pb.PbApiError))
  ApiReturnedUser(Result(User, pb.PbApiError))
  ApiReturnedAccouchement(Result(Accouchement, pb.PbApiError))

  AuthReadFromStorage(Result(pb.Auth(User), pb.PbStorageError))
  AuthWrittenInStorage(Result(Nil, pb.PbStorageError))
  AuthDeletedFromStorage(Result(Nil, pb.PbStorageError))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model {
    LoggedOut -> update_logged_out(msg)
    LoggedIn(token:, user:, page:) ->
      update_logged_in(msg:, token:, user:, page:)
  }
}

fn update_logged_out(msg) {
  let ignore = #(LoggedOut, effect.none())
  case msg {
    UserSubmittedLoginForm(Ok(login_data)) -> #(
      LoggedOut,
      server_login(login_data),
    )
    UserSubmittedLoginForm(..) -> ignore
    AuthReadFromStorage(Ok(auth)) -> #(
      LoggedIn(token: auth.token, user: auth.record, page: PageAccueil),
      effect.none(),
    )
    AuthReadFromStorage(Error(_)) -> ignore
    ApiReturnedAuth(Ok(auth)) -> #(
      LoggedIn(token: auth.token, user: auth.record, page: PageAccueil),
      store_auth(auth),
    )
    ApiReturnedAuth(Error(_)) -> todo
    _ -> ignore
  }
}

fn update_logged_in(msg msg, token token, user user, page page) {
  let model = LoggedIn(token:, user:, page:)
  let ignore = #(model, effect.none())
  case msg {
    UserClickedDock(location) -> {
      let new_page = case location {
        "Accouchement" -> new_page_accouchement(user)
        "Profil" -> PageProfil
        "Accueil" -> PageAccueil
        _ -> page
      }
      let model = LoggedIn(..model, page: new_page)
      #(model, effect.none())
    }
    UserClickedLogout -> #(LoggedOut, delete_auth_from_storage())

    UserChangedAnswerAccouchement(update) -> {
      let assert PageAccouchement(acc_questions:, ..) = page
      let new_questions = acc.update_questions(acc_questions, update)
      #(
        LoggedIn(
          ..model,
          page: PageAccouchement(..page, acc_questions: new_questions),
        ),
        effect.none(),
      )
    }
    UserChangedAnswerUser(update) -> {
      let new_user = user.update_user(user, update)
      let model = LoggedIn(..model, user: new_user)
      let model = case page {
        PageAccouchement(user_questions:, acc_questions:) -> {
          let user_questions = user.update_questions(user_questions, update)
          LoggedIn(
            ..model,
            page: PageAccouchement(user_questions, acc_questions),
          )
        }
        _ -> model
      }
      #(model, server_update_user(token, new_user))
    }

    UserSubmittedLoginForm(Ok(login_data)) -> #(model, server_login(login_data))
    UserSubmittedLoginForm(_) -> #(model, effect.none())
    UserSubmittedUserUpdate(_) -> {
      todo
    }
    UserClickedSubmitAccouchement -> {
      todo
    }

    ApiReturnedAuth(Ok(auth)) -> #(
      LoggedIn(..model, token: auth.token, user: auth.record),
      store_auth(auth),
    )
    ApiReturnedAuth(Error(_)) -> todo
    ApiReturnedUser(Ok(new_user)) -> {
      let assert LoggedIn(token, user, page) = model
      #(
        LoggedIn(token:, user: new_user, page:),
        store_auth(pb.Auth(token:, record: new_user)),
      )
    }
    ApiReturnedUser(Error(_)) -> todo
    ApiReturnedAccouchement(Ok(_accouchement)) -> todo
    ApiReturnedAccouchement(Error(_)) -> todo

    AuthReadFromStorage(Ok(auth)) -> #(
      LoggedIn(..model, token: auth.token, user: auth.record),
      effect.none(),
    )
    AuthReadFromStorage(Error(_)) -> ignore
    AuthWrittenInStorage(Ok(_)) -> ignore
    AuthWrittenInStorage(Error(_)) -> ignore
    AuthDeletedFromStorage(Ok(_)) -> ignore
    AuthDeletedFromStorage(Error(_)) -> ignore
  }
}

fn new_page_accouchement(user: User) {
  PageAccouchement(
    user_questions: user.new_questions(user),
    acc_questions: acc.new_questions(),
  )
}

// EFFECTS ------------------------------------------------------------------------

fn read_auth_from_storage() {
  use dispatch <- effect.from()
  pb.read_auth_from_storage(user.decode())
  |> AuthReadFromStorage
  |> dispatch
}

fn store_auth(auth) {
  use dispatch <- effect.from()
  pb.write_auth_to_storage(auth, user.encode)
  |> AuthWrittenInStorage
  |> dispatch
}

fn delete_auth_from_storage() {
  use dispatch <- effect.from()
  pb.logout()
  |> AuthDeletedFromStorage
  |> dispatch
}

type LoginData {
  LoginData(username: String, password: String)
}

fn server_login(login_data: LoginData) -> Effect(Msg) {
  use dispatch <- effect.from()
  pb.auth_with_password(
    server,
    login_data.username,
    login_data.password,
    user.decode(),
  )
  |> promise.map(ApiReturnedAuth)
  |> promise.tap(dispatch)
  Nil
}

fn server_get_user(token: String, user_id: String) {
  use dispatch <- effect.from()
  pb.get_one_record(server, Some(token), "users", user_id, user.decode())
  |> promise.map(ApiReturnedUser)
  |> promise.tap(dispatch)
  Nil
}

fn server_update_user(token: String, user: User) {
  use dispatch <- effect.from()
  pb.update_one_record(
    server,
    Some(token),
    "users",
    user.id,
    user.encode(user),
    user.decode(),
  )
  |> promise.map(ApiReturnedUser)
  |> promise.tap(dispatch)
  Nil
}

fn server_create_accouchement(token: String, del: Accouchement) -> Effect(Msg) {
  use dispatch <- effect.from()
  pb.create_one_record(
    server,
    Some(token),
    "accouchements",
    acc.encode(del),
    acc.decode(),
  )
  |> promise.map(ApiReturnedAccouchement)
  |> promise.tap(dispatch)
  Nil
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model {
    LoggedOut -> view_login()
    LoggedIn(_, user, page) -> view_logged_in(user, page)
  }
}

fn view_logged_in(user, page) {
  case page {
    PageProfil ->
      view_profil(user)
      |> base_view(page)
    PageAccouchement(user_questions:, acc_questions:) ->
      view_accouchement(user_questions:, acc_questions:)
      |> base_view(page)
    PageAccueil ->
      view_accueil()
      |> base_view(page)
  }
}

fn base_view(inner: Element(Msg), page: Page) -> Element(Msg) {
  let buttons = [
    #("Accueil", icons.home_icon()),
    #("Accouchement", icons.baby_icon()),
    #("Profil", icons.user_icon()),
  ]
  html.div([attribute.class("min-h-full mx-auto bg-base-100")], [
    nav_bar(),
    html.div([attribute.class("px-4 py-8 mx-auto max-w-[100rem]")], [inner]),
    components.render_dock(
      buttons:,
      active_page: page_name(page),
      on_click: UserClickedDock,
    ),
  ])
}

fn nav_bar() {
  html.div([attribute.class("navbar bg-base-200 shadow-sm")], [
    html.div([attribute.class("navbar-start")], []),
    html.div([attribute.class("navbar-center")], [html.text("Test")]),
    html.div([attribute.class("navbar-end")], []),
  ])
}

fn view_profil(user: User) -> Element(Msg) {
  html.div([attribute.class("")], [
    html.main([attribute.class("")], [view_user_form(user)]),
    html.button([attribute.class("btn"), event.on_click(UserClickedLogout)], [
      html.text("Se déconnecter"),
    ]),
  ])
}

fn user_msg(question) {
  fn(answer) { UserChangedAnswerUser(#(question, answer.Proposed(answer))) }
}

fn view_user_form(user: User) -> Element(Msg) {
  let handle_submit = fn(form_data) {
    form.decoding({
      use sexe <- form.parameter
      use semestre <- form.parameter

      user.User(
        ..user,
        sexe: string.to_option(sexe),
        semestre: string.to_option(semestre),
      )
    })
    |> form.with_values(form_data)
    |> form.field("sexe", form.string)
    |> form.field("semestre", form.string)
    |> form.finish
    |> UserSubmittedUserUpdate()
  }
  let sexe = option.unwrap(user.sexe, "")
  let semestre = option.unwrap(user.semestre, "")
  let sexe_message = user_msg(user.Sexe)
  let semestre_message = user_msg(user.Semestre)

  html.form([event.on_submit(handle_submit), attribute.class("")], [
    fieldsets.sexe(sexe, Some(sexe_message)),
    fieldsets.semestre(semestre, Some(semestre_message)),
    html.button([attribute.class("btn"), attribute.type_("submit")], [
      html.text("Enregistrer"),
    ]),
  ])
}

fn view_login() -> Element(Msg) {
  login_form()
}

fn login_form() -> Element(Msg) {
  let handle_submit = fn(form_data) {
    form.decoding({
      use username <- form.parameter
      use password <- form.parameter

      LoginData(username:, password:)
    })
    |> form.with_values(form_data)
    |> form.field("username", form.string |> form.and(form.must_not_be_empty))
    |> form.field(
      "password",
      form.string |> form.and(form.must_be_string_longer_than(8)),
    )
    |> form.finish
    |> UserSubmittedLoginForm
  }

  html.form([event.on_submit(handle_submit)], [
    html.fieldset(
      [
        attribute.class(
          "fieldset bg-base-200 border-base-300 rounded-box w-xs border p-4",
        ),
      ],
      [
        html.legend([attribute.class("fieldset-legend")], [html.text("Login")]),
        html.label([attribute.class("label")], [html.text("Username")]),
        html.input([
          attribute.class("input"),
          attribute.placeholder("Username"),
          attribute.name("username"),
          attribute.type_("text"),
        ]),
        html.label([attribute.class("label")], [html.text("Password")]),
        html.input([
          attribute.class("input"),
          attribute.placeholder("Password"),
          attribute.name("password"),
          attribute.type_("password"),
        ]),
        html.button([attribute.class("btn")], [html.text("Login")]),
      ],
    ),
  ])
}

fn view_accueil() {
  html.div([attribute.class("stats shadow ")], [
    html.div([attribute.class("stat")], [
      html.div([attribute.class("stat-title")], [html.text("Total Page Views")]),
      html.div([attribute.class("stat-value")], [html.text("89,400")]),
      html.div([attribute.class("stat-desc")], [
        html.text("21% more than last month"),
      ]),
    ]),
  ])
}

fn render_question_raison(answer, autonomie) {
  let raison_params =
    fieldsets.RaisonFieldSetParams(
      radio_checked: case answer {
        answer.Proposed(raison) -> raison
        answer.Other(_raison) -> "autre"
        answer.NoAnswer -> ""
      },
      on_radio_change: Some(fn(input) {
        UserChangedAnswerAccouchement(
          #(acc.Raison(autonomie), case input {
            "autre" -> answer.Other("")
            _ -> answer.Proposed(input)
          }),
        )
      }),
      input_is_disabled: case answer {
        answer.Proposed(_raison) -> True
        answer.Other(_raison) -> False
        answer.NoAnswer -> True
      },
      input_value: case answer {
        answer.Other(raison) -> raison
        _ -> ""
      },
      on_input_change: Some(fn(input) {
        UserChangedAnswerAccouchement(#(
          acc.Raison(autonomie),
          answer.Other(input),
        ))
      }),
    )
  case autonomie {
    acc.Observe -> fieldsets.raison_observe(raison_params)
    acc.AideActive -> fieldsets.raison_aide_active(raison_params)
    acc.AideMineure -> fieldsets.raison_aide_mineure(raison_params)
  }
}

fn view_accouchement(
  user_questions user_questions,
  acc_questions acc_questions,
) -> Element(Msg) {
  let user_questions_order = [user.Sexe, user.Semestre]
  let rendered_user_questions =
    user_questions
    |> dict.map_values(fn(question, answer) {
      case question {
        user.Sexe ->
          fieldsets.sexe(answer.to_string(answer), Some(user_msg(user.Sexe)))
        user.Semestre ->
          fieldsets.semestre(
            answer.to_string(answer),
            Some(user_msg(user.Semestre)),
          )
      }
    })
  let rendered_user_questions =
    list.filter_map(user_questions_order, fn(question) {
      dict.get(rendered_user_questions, question)
    })

  let acc_msg = fn(question) {
    fn(answer) {
      UserChangedAnswerAccouchement(#(question, answer.Proposed(answer)))
    }
  }

  let acc_questions_order = [
    acc.PosteChef,
    acc.Moment,
    acc.Instrument,
    acc.Autonomie,
    acc.Raison(acc.Observe),
    acc.Raison(acc.AideActive),
    acc.Raison(acc.AideMineure),
  ]
  let rendered_acc_questions =
    acc_questions
    |> dict.map_values(fn(question, answer) {
      case question {
        acc.PosteChef ->
          fieldsets.poste_chef(
            answer.to_string(answer),
            Some(acc_msg(acc.PosteChef)),
          )
        acc.Moment ->
          fieldsets.moment(answer.to_string(answer), Some(acc_msg(acc.Moment)))
        acc.Instrument ->
          fieldsets.instrument(
            answer.to_string(answer),
            Some(acc_msg(acc.Instrument)),
          )
        acc.Autonomie ->
          fieldsets.autonomie(
            answer.to_string(answer),
            Some(acc_msg(acc.Autonomie)),
          )
        acc.Raison(raison) -> render_question_raison(answer, raison)
      }
    })
  let rendered_acc_questions =
    list.filter_map(acc_questions_order, fn(question) {
      dict.get(rendered_acc_questions, question)
    })
  html.form(
    [attribute.class("")],
    list.flatten([
      rendered_user_questions,
      rendered_acc_questions,
      [
        html.button(
          [
            attribute.class("btn"),
            event.on_click(UserClickedSubmitAccouchement),
          ],
          [html.text("Enregistrer")],
        ),
      ],
    ]),
  )
}
