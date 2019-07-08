//
//  CardFieldViewController.swift
//  UI Examples
//
//  Created by Ben Guo on 7/19/17.
//  Copyright © 2017 Stripe. All rights reserved.
//

import UIKit
import Stripe

class CardFieldViewController: UIViewController {

    let cardField = STPPaymentCardTextField()
    var theme = STPTheme.default()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Card Field"
        view.backgroundColor = UIColor.white
        view.addSubview(cardField)
        edgesForExtendedLayout = []
        view.backgroundColor = UIColor.black

        cardField.backgroundColor = UIColor.clear
        cardField.textColor = UIColor.white
        cardField.placeholderColor = UIColor.lightGray
        cardField.borderColor = UIColor.white
        cardField.borderWidth = 1.0
        cardField.textErrorColor = UIColor.red
        
        let views: [String: Any] = [
            "cardField": cardField]
        cardField.translatesAutoresizingMaskIntoConstraints = false;
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[cardField]-|", metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-30-[cardField]", metrics: nil, views: views))

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        navigationController?.navigationBar.stp_theme = theme
    }

    @objc func done() {
        dismiss(animated: true, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }


}
