import DesignSystem
import Env
import Models
import Network
import SwiftUI

public struct StatusPollView: View {
  @EnvironmentObject private var theme: Theme
  @EnvironmentObject private var client: Client
  @EnvironmentObject private var currentInstance: CurrentInstance
  @EnvironmentObject private var currentAccount: CurrentAccount
  @StateObject private var viewModel: StatusPollViewModel

  private var status: AnyStatus

  public init(poll: Poll, status: AnyStatus) {
    _viewModel = StateObject(wrappedValue: .init(poll: poll))
    self.status = status
  }

  private func widthForOption(option: Poll.Option, proxy: GeometryProxy) -> CGFloat {
    if viewModel.poll.safeVotersCount != 0 {
      let totalWidth = proxy.frame(in: .local).width
      return totalWidth * ratioForOption(option: option)
    } else {
      return 0
    }
  }

  private func percentForOption(option: Poll.Option) -> Int {
    let percent = ratioForOption(option: option) * 100
    return Int(round(percent))
  }

  private func ratioForOption(option: Poll.Option) -> CGFloat {
    if viewModel.poll.safeVotersCount != 0 {
      return CGFloat(option.votesCount) / CGFloat(viewModel.poll.safeVotersCount)
    } else {
      return 0.0
    }
  }

  private func isSelected(option: Poll.Option) -> Bool {
    if let optionIndex = viewModel.poll.options.firstIndex(where: { $0.id == option.id }),
       let _ = viewModel.votes.firstIndex(of: optionIndex)
    {
      return true
    }
    return false
  }

  private func buttonImage(option: Poll.Option) -> some View {
    let isSelected = isSelected(option: option)
    var imageName = ""
    if viewModel.poll.multiple {
      if isSelected {
        imageName = "checkmark.square"
      } else {
        imageName = "square"
      }
    } else {
      if isSelected {
        imageName = "record.circle"
      } else {
        imageName = "circle"
      }
    }
    return Image(systemName: imageName)
      .foregroundColor(theme.labelColor)
  }

  public var body: some View {
    VStack(alignment: .leading) {
      ForEach(viewModel.poll.options) { option in
        HStack {
          makeBarView(for: option, buttonImage: buttonImage(option: option))
            .disabled(viewModel.poll.expired || (viewModel.poll.voted ?? false))
          if viewModel.showResults || status.account.id == currentAccount.account?.id {
            Spacer()
            // Make sure they're all the same width using a ZStack with 100% hiding behind the
            // real percentage.
            ZStack(alignment: .trailing) {
              Text("100%")
                .hidden()

              Text("\(percentForOption(option: option))%")
                .font(.scaledSubheadline)
            }
          }
        }
      }
      if !viewModel.poll.expired, !(viewModel.poll.voted ?? false), !viewModel.votes.isEmpty {
        Button("status.poll.send") {
          Task {
            do {
              await viewModel.postVotes()
            }
          }
        }
        .buttonStyle(.bordered)
      }
      footerView

    }.onAppear {
      viewModel.instance = currentInstance.instance
      viewModel.client = client
      Task {
        await viewModel.fetchPoll()
      }
    }
  }

  private var footerView: some View {
    HStack(spacing: 0) {
      if viewModel.poll.multiple {
        Text("status.poll.n-votes-voters \(viewModel.poll.votesCount) \(viewModel.poll.safeVotersCount)")
      } else {
        Text("status.poll.n-votes \(viewModel.poll.votesCount)")
      }
      Text(" ⸱ ")
      if viewModel.poll.expired {
        Text("status.poll.closed")
      } else if let date = viewModel.poll.expiresAt.value?.asDate {
        Text("status.poll.closes-in")
        Text(date, style: .timer)
      }
    }
    .font(.scaledFootnote)
    .foregroundColor(.gray)
  }

  @ViewBuilder
  private func makeBarView(for option: Poll.Option, buttonImage: some View) -> some View {
    Button {
      if !viewModel.poll.expired,
         let index = viewModel.poll.options.firstIndex(where: { $0.id == option.id })
      {
        withAnimation {
          viewModel.handleSelection(index)
        }
      }
    } label: {
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Rectangle()
            .background {
              if viewModel.showResults || status.account.id == currentAccount.account?.id {
                HStack {
                  let width = widthForOption(option: option, proxy: proxy)
                  Rectangle()
                    .foregroundColor(theme.tintColor)
                    .frame(height: .pollBarHeight)
                    .frame(width: width)
                  if width != proxy.size.width {
                    Spacer()
                  }
                }
              }
            }
            .foregroundColor(theme.tintColor.opacity(0.40))
            .frame(height: .pollBarHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))

          HStack {
            buttonImage
            Text(option.title)
              .foregroundColor(theme.labelColor)
              .font(.scaledBody)
              .minimumScaleFactor(0.7)
          }
          .padding(.leading, 12)
        }
      }
      .frame(height: .pollBarHeight)
    }
    .buttonStyle(.borderless)
  }
}
