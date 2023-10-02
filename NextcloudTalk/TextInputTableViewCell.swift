//
// Copyright (c) 2022 Aleksandra Lazarevic <aleksandra@nextcloud.com>
//
// Author Aleksandra Lazarevic <aleksandra@nextcloud.com>
//
// GNU GPL version 3 or any later version
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

let kTextInputCellIdentifier = "TextInputCellIdentifier"
let kTextInputTableViewCellNibName = "TextInputTableViewCell"

class TextInputTableViewCell: UITableViewCell {

    @IBOutlet weak var textField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.textField.clearButtonMode = .whileEditing
        self.textField.returnKeyType = .done
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.textField.text = ""
        self.textField.placeholder = nil
        self.textField.keyboardType = .default
        self.textField.autocorrectionType = .no
    }
}
