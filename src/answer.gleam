import gleam/dict.{type Dict}

pub type Answer {
  Proposed(String)
  Other(String)
  NoAnswer
}

pub fn to_string(answer: Answer) {
  case answer {
    Proposed(choice) -> choice
    Other(choice) -> choice
    NoAnswer -> ""
  }
}

pub type Error {
  MissingAnswerError
  EmptyOtherError
}

pub fn validate_single(answer) {
  case answer {
    Proposed(choice) -> Ok(choice)
    Other("") -> Error(EmptyOtherError)
    Other(input) -> Ok(input)
    NoAnswer -> Error(MissingAnswerError)
  }
}

pub fn validate_multiple(
  questions: Dict(a, Answer),
) -> Result(Dict(a, String), Dict(a, Error)) {
  questions
  |> dict.fold(Ok(dict.new()), fn(accumulator, question, answer) {
    case accumulator, validate_single(answer) {
      Ok(acc), Ok(answer) -> Ok(dict.insert(acc, question, answer))
      Ok(_acc), Error(answer) -> Error(dict.from_list([#(question, answer)]))
      Error(acc), Ok(_answer) -> Error(acc)
      Error(acc), Error(answer) -> Error(dict.insert(acc, question, answer))
    }
  })
}
