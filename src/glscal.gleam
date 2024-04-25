import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

type Message {
  Set(next: Subject(Message))
  Pass
}

type State {
  State(value: Int, next: Option(Subject(Message)))
}

fn loop(message: Message, state: State) {
  case message {
    Set(next) -> {
      actor.continue(State(..state, next: Some(next)))
    }
    Pass -> {
      state.value
      |> int.to_string
      |> io.println
      actor.continue(state)
    }
  }
}

fn build_rec(first: Subject(Message), acc: Int) {
  case acc {
    0 -> []
    x -> {
      case build_rec(first, x - 1) {
        [] -> {
          let assert Ok(last) = actor.start(State(0, Some(first)), loop)
          [last]
        }
        [head, ..tail] -> {
          let assert Ok(next) = actor.start(State(x, Some(head)), loop)
          [next, head, ..tail]
        }
      }
    }
  }
}

fn build(n: Int) {
  let assert Ok(first) = actor.start(State(n, None), loop)
  build_rec(first, n - 1)
}

pub fn main() {
  io.println("Hello from glscal!")

  build(100)
  |> list.each(actor.send(_, Pass))

  process.sleep_forever()
}
