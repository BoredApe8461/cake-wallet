import 'package:cake_wallet/ionia/ionia_create_state.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/ionia/widgets/text_icon_button.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/ionia/ionia_view_model.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:mobx/mobx.dart';

class IoniaActivateDebitCardPage extends BasePage {
  final IoniaViewModel _ioniaViewModel;

  IoniaActivateDebitCardPage(this._ioniaViewModel);

  @override
  Widget middle(BuildContext context) {
    return Text(
      S.current.debit_card,
      style: TextStyle(
        fontSize: 22,
        fontFamily: 'Lato',
        fontWeight: FontWeight.w900,
      ),
    );
  }

  @override
  Widget body(BuildContext context) {
    reaction((_) => _ioniaViewModel.createCardState, (IoniaCreateCardState state) {
      if (state is IoniaCreateCardFailure) {
        _onCreateCardFailure(context, state.error);
      }
      if (state is IoniaCreateCardSuccess) {
        _onCreateCardSuccess(context);
      }
    });
    return ScrollableWithBottomSection(
      contentPadding: EdgeInsets.zero,
      content: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 16),
            Text(S.of(context).debit_card_terms),
            SizedBox(height: 24),
            Text(S.of(context).please_reference_document),
            SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  TextIconButton(
                    label: S.current.cardholder_agreement,
                    onTap: () {},
                  ),
                  SizedBox(
                    height: 24,
                  ),
                  TextIconButton(
                    label: S.current.e_sign_consent,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSection: LoadingPrimaryButton(
        onPressed: () {
          _ioniaViewModel.createCard();
        },
        isLoading: _ioniaViewModel.createCardState is IoniaCreateCardLoading,
        text: S.of(context).agree_and_continue,
        color: Theme.of(context).accentTextTheme.body2.color,
        textColor: Colors.white,
      ),
    );
  }
}

void _onCreateCardFailure(BuildContext context, String errorMessage) {
  showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertWithOneAction(
            alertTitle: S.current.error,
            alertContent: errorMessage,
            buttonText: S.of(context).ok,
            buttonAction: () => Navigator.of(context).pop());
      });
}

void _onCreateCardSuccess(BuildContext context) {
  Navigator.pushNamed(
    context,
    Routes.ioniaDebitCardPage,
  );
  showPopUp<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertWithOneAction(
        alertTitle: 'Congratulations!',
        alertContent: 'You now have a debit card',
        buttonText: S.of(context).ok,
        buttonAction: () => Navigator.of(context).pop(),
      );
    },
  );
}
